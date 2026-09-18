# Spoke-to-hub VNet peering.
#
# The hub-and-spoke module meshes the hubs to each other but knows nothing about
# spokes, so both directions are created here. They go through `azapi` because
# the spoke side lives in the workload's own subscription and azapi addresses a
# resource by its full ID rather than through a per-subscription provider alias.

locals {
  spoke_peerings = local.connectivity_hub_and_spoke_vnet_enabled ? var.spoke_virtual_network_peerings : {}

  spoke_peering_hub_virtual_network_ids = {
    for key, peering in local.spoke_peerings :
    key => module.hub_and_spoke_vnet[0].virtual_network_resource_ids[peering.hub_key]
  }
}

resource "azapi_resource" "hub_to_spoke_peering" {
  provider = azapi.connectivity

  for_each = local.spoke_peerings

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = coalesce(each.value.hub_to_spoke_peering_name, "peer-${each.value.hub_key}-to-${each.key}")
  parent_id = local.spoke_peering_hub_virtual_network_ids[each.key]

  body = {
    properties = {
      remoteVirtualNetwork      = { id = each.value.spoke_virtual_network_resource_id }
      allowVirtualNetworkAccess = each.value.allow_virtual_network_access
      allowForwardedTraffic     = each.value.allow_forwarded_traffic
      allowGatewayTransit       = each.value.hub_allow_gateway_transit
      useRemoteGateways         = false
    }
  }
}

resource "azapi_resource" "spoke_to_hub_peering" {
  provider = azapi.connectivity

  for_each = local.spoke_peerings

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = coalesce(each.value.spoke_to_hub_peering_name, "peer-${each.key}-to-${each.value.hub_key}")
  parent_id = each.value.spoke_virtual_network_resource_id

  body = {
    properties = {
      remoteVirtualNetwork      = { id = local.spoke_peering_hub_virtual_network_ids[each.key] }
      allowVirtualNetworkAccess = each.value.allow_virtual_network_access
      allowForwardedTraffic     = each.value.allow_forwarded_traffic
      allowGatewayTransit       = false
      useRemoteGateways         = each.value.spoke_use_remote_gateways
    }
  }

  # Azure rejects the second half of a peering while the first is still being
  # written, so the two sides are ordered rather than created in parallel.
  depends_on = [azapi_resource.hub_to_spoke_peering]
}
