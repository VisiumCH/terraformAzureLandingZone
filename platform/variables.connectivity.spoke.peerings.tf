variable "spoke_virtual_network_peerings" {
  type = map(object({
    hub_key                           = string
    spoke_virtual_network_resource_id = string
    hub_to_spoke_peering_name         = optional(string)
    spoke_to_hub_peering_name         = optional(string)
    allow_virtual_network_access      = optional(bool, true)
    allow_forwarded_traffic           = optional(bool, true)
    hub_allow_gateway_transit         = optional(bool, false)
    spoke_use_remote_gateways         = optional(bool, false)
  }))
  default     = {}
  description = <<DESCRIPTION
Spoke VNets to peer to a hub, keyed by a short spoke name. Both directions of
each peering are created, so the deploy identity needs write access on the
spoke's virtual network as well as the hub's.

  - hub_key: the `hub_virtual_networks` key of the hub to peer to
  - spoke_virtual_network_resource_id: the spoke VNet's full resource ID
  - hub_to_spoke_peering_name / spoke_to_hub_peering_name: (Optional) peering
    names; default to `peer-<hub>-to-<key>` and `peer-<key>-to-<hub>`
  - allow_forwarded_traffic: (Optional) defaults true, so traffic the hub's VPN
    routers or firewall forward is accepted
  - hub_allow_gateway_transit / spoke_use_remote_gateways: (Optional) set both
    when the hub has a VPN or ExpressRoute gateway the spoke should use

Spokes in `visium-sandbox` cannot be listed here: `SandboxDenyVnetPeering` blocks
the peering, and sandbox isolation is deliberate.
DESCRIPTION

  validation {
    condition = alltrue([
      for key, peering in var.spoke_virtual_network_peerings :
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", peering.spoke_virtual_network_resource_id))
    ])
    error_message = "Each spoke_virtual_network_resource_id must be a full virtual network resource ID."
  }

  validation {
    condition = alltrue([
      for key, peering in var.spoke_virtual_network_peerings :
      peering.spoke_use_remote_gateways ? peering.hub_allow_gateway_transit : true
    ])
    error_message = "spoke_use_remote_gateways requires hub_allow_gateway_transit on the same peering."
  }
}
