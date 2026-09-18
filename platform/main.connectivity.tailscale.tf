# Tailscale subnet routers — the platform's VPN entry point into the hubs.
#
# Each router is a small Linux VM in the hub's `snet-vpn` subnet that advertises
# the regional hub address spaces into the tailnet. Two of them advertising the
# same routes give Tailscale an HA pair with automatic failover.
#
# Reachability: the routers carry a public IP so Tailscale can build direct UDP
# connections instead of relaying through DERP. The NSG lets nothing in from the
# internet except Tailscale's UDP port; there is no inbound SSH. Administration
# is Tailscale SSH over the tailnet.

locals {
  tailscale_routers = local.connectivity_hub_and_spoke_vnet_enabled ? var.tailscale_subnet_routers : {}

  tailscale_resource_group = try(module.config.outputs.connectivity_resource_groups[var.tailscale_resource_group_key], null)

  # One NSG per region the routers land in.
  tailscale_hub_keys = toset([for router in local.tailscale_routers : router.hub_key])

  tailscale_hub_locations = {
    for hub_key in local.tailscale_hub_keys :
    hub_key => module.config.outputs.hub_virtual_networks[hub_key].location
  }

  tailscale_subnet_ids = {
    for key, router in local.tailscale_routers :
    key => "${module.hub_and_spoke_vnet[0].virtual_network_resource_ids[router.hub_key]}/subnets/${router.subnet_name}"
  }
}

# Break-glass key only. The routers have no inbound SSH from the internet, so
# this is reachable over the tailnet (or serial console) and nowhere else.
resource "tls_private_key" "tailscale" {
  count = length(local.tailscale_routers) > 0 ? 1 : 0

  algorithm = "ED25519"
}

resource "azurerm_network_security_group" "tailscale" {
  provider = azurerm.connectivity

  for_each = local.tailscale_hub_locations

  name                = "nsg-vpn-${each.value}"
  location            = each.value
  resource_group_name = local.tailscale_resource_group.name
  tags                = coalesce(var.connectivity_tags, var.tags)

  # Tailscale's direct-connection port. Without it peers fall back to relaying
  # through DERP, which still works but costs latency and throughput.
  security_rule {
    name                       = "Allow-Tailscale-Direct-UDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "41641"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Tailnet peers (CGNAT range) reaching the router itself, including Tailscale SSH.
  security_rule {
    name                       = "Allow-Tailnet-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "100.64.0.0/10"
    destination_address_prefix = "*"
  }

  depends_on = [module.resource_groups]
}

# A known, tagged, Terraform-managed public resource. Creating it fires the
# public-resource Slack alert — that is expected, not a surprise.
resource "azurerm_public_ip" "tailscale" {
  provider = azurerm.connectivity

  for_each = local.tailscale_routers

  name                = "pip-tailscale-${each.key}"
  location            = local.tailscale_hub_locations[each.value.hub_key]
  resource_group_name = local.tailscale_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = each.value.zone == null ? null : [each.value.zone]
  tags                = coalesce(var.connectivity_tags, var.tags)

  depends_on = [module.resource_groups]
}

resource "azurerm_network_interface" "tailscale" {
  provider = azurerm.connectivity

  for_each = local.tailscale_routers

  name                  = "nic-tailscale-${each.key}"
  location              = local.tailscale_hub_locations[each.value.hub_key]
  resource_group_name   = local.tailscale_resource_group.name
  ip_forwarding_enabled = true # required for the VM to forward traffic it does not own
  tags                  = coalesce(var.connectivity_tags, var.tags)

  ip_configuration {
    name                          = "ipconfig-primary"
    subnet_id                     = local.tailscale_subnet_ids[each.key]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tailscale[each.key].id
  }

  depends_on = [module.resource_groups]
}

resource "azurerm_network_interface_security_group_association" "tailscale" {
  provider = azurerm.connectivity

  for_each = local.tailscale_routers

  network_interface_id      = azurerm_network_interface.tailscale[each.key].id
  network_security_group_id = azurerm_network_security_group.tailscale[each.value.hub_key].id
}

resource "azurerm_linux_virtual_machine" "tailscale" {
  provider = azurerm.connectivity

  for_each = local.tailscale_routers

  name                            = "vm-tailscale-${each.key}"
  location                        = local.tailscale_hub_locations[each.value.hub_key]
  resource_group_name             = local.tailscale_resource_group.name
  size                            = each.value.vm_size
  zone                            = each.value.zone
  admin_username                  = var.tailscale_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.tailscale[each.key].id]
  tags                            = coalesce(var.connectivity_tags, var.tags)

  # Trusted Launch: free, and it satisfies Audit-TrustedLaunch and the guest
  # attestation policy that applies under visium-platform.
  secure_boot_enabled = true
  vtpm_enabled        = true

  admin_ssh_key {
    username   = var.tailscale_admin_username
    public_key = tls_private_key.tailscale[0].public_key_openssh
  }

  os_disk {
    name                 = "osdisk-tailscale-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {} # managed storage, no storage account to own

  custom_data = base64encode(templatefile("${path.module}/templates/tailscale-subnet-router.yaml.tftpl", {
    auth_key         = var.tailscale_auth_key
    hostname         = "azure-hub-${each.key}"
    advertise_routes = join(",", var.tailscale_advertise_routes)
  }))

  lifecycle {
    # cloud-init only runs on first boot, so re-rendering it (a rotated auth key,
    # a changed route list) must not silently replace a working router. Rebuild
    # deliberately with `terraform taint` instead.
    ignore_changes = [custom_data]

    precondition {
      condition     = var.tailscale_auth_key != ""
      error_message = "tailscale_auth_key must be set when tailscale_subnet_routers is non-empty."
    }

    precondition {
      condition     = length(var.tailscale_advertise_routes) > 0
      error_message = "tailscale_advertise_routes must list at least one CIDR for the routers to advertise."
    }
  }
}
