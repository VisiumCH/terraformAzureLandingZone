variable "tailscale_subnet_routers" {
  type = map(object({
    hub_key     = string
    subnet_name = string
    zone        = optional(string)
    vm_size     = optional(string, "Standard_B2ts_v2")
  }))
  default     = {}
  description = <<DESCRIPTION
Tailscale subnet routers to deploy into the hub VNets, keyed by a short instance
name (used in the resource and tailnet hostnames).

  - hub_key: the `hub_virtual_networks` key whose VNet hosts the router
  - subnet_name: the subnet inside that VNet the router's NIC lands in
  - zone: (Optional) availability zone to pin the VM to
  - vm_size: (Optional) VM size, defaults to Standard_B2ts_v2

Two or more routers advertising the same routes give Tailscale an HA pair: the
tailnet fails over between them once both are approved as subnet routers.
DESCRIPTION
}

variable "tailscale_auth_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = <<DESCRIPTION
Tailscale auth key the routers use to join the tailnet on first boot. Use a
reusable, pre-approved, tagged key; it is passed through cloud-init, so rotate
it after the routers are up. Required when `tailscale_subnet_routers` is set.
DESCRIPTION
}

variable "tailscale_advertise_routes" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
CIDRs the subnet routers advertise into the tailnet. Normally the regional hub
address spaces, so the routes stay valid as spokes are carved out of them. The
routes still have to be approved once in the Tailscale admin console.
DESCRIPTION
}

variable "tailscale_resource_group_key" {
  type        = string
  default     = "vpn"
  description = "The `connectivity_resource_groups` key of the resource group the routers are deployed into."
}

variable "tailscale_admin_username" {
  type        = string
  default     = "azureuser"
  description = "Local admin username on the router VMs. Day-to-day access is Tailscale SSH; this is the break-glass account."
}
