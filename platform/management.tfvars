# Visium greenfield platform landing zone — inputs for the ALZ accelerator.
# Tokens like $${starter_location_01} are accelerator built-in replacements.

# Multi-region: primary Switzerland North (billing + residency), secondary Sweden Central (LLM/DR).
starter_locations = ["switzerlandnorth", "swedencentral"]

# The `visium` intermediate root is created directly under the TENANT ROOT
# (tenant-root management-group id == the Entra tenant id).
root_parent_management_group_id = "b7418ead-a445-4708-a309-951ab14852eb"

# `connectivity` points at the Management sub for now (no dedicated connectivity
# sub yet) so the hub network + private DNS land there. `identity` is reserved.
subscription_ids = {
  management   = "8745729a-505a-4910-aaaf-d53b9cdc8883"
  connectivity = "8745729a-505a-4910-aaaf-d53b9cdc8883"
  identity     = "8745729a-505a-4910-aaaf-d53b9cdc8883"
}

custom_replacements = {
  names = {
    defender_email_security_contact = "pascal.rodriguez@visium.ch"

    # --- Connectivity feature toggles (keep costs down) ---
    ddos_protection_plan_enabled = false

    # Primary connectivity: NO firewall / bastion / gateways; private DNS zones ON; resolver OFF
    primary_firewall_enabled                                             = false
    primary_firewall_sku_tier                                            = "Standard"
    primary_firewall_management_ip_enabled                               = false
    primary_virtual_network_gateway_express_route_enabled                = false
    primary_virtual_network_gateway_express_route_hobo_public_ip_enabled = false
    primary_virtual_network_gateway_vpn_enabled                          = false
    primary_private_dns_zones_enabled                                    = true
    primary_private_dns_auto_registration_zone_enabled                   = true
    primary_private_dns_resolver_enabled                                 = false
    primary_bastion_enabled                                              = false

    # Secondary connectivity: same posture
    secondary_firewall_enabled                                             = false
    secondary_firewall_sku_tier                                            = "Standard"
    secondary_firewall_management_ip_enabled                               = false
    secondary_virtual_network_gateway_express_route_enabled                = false
    secondary_virtual_network_gateway_express_route_hobo_public_ip_enabled = false
    secondary_virtual_network_gateway_vpn_enabled                          = false
    secondary_private_dns_zones_enabled                                    = true
    secondary_private_dns_auto_registration_zone_enabled                   = true
    secondary_private_dns_resolver_enabled                                 = false
    secondary_bastion_enabled                                              = false

    # Resource group names
    management_resource_group_name                 = "rg-management-$${starter_location_01}"
    connectivity_hub_primary_resource_group_name   = "rg-hub-$${starter_location_01}"
    connectivity_hub_secondary_resource_group_name = "rg-hub-$${starter_location_02}"
    dns_resource_group_name                        = "rg-hub-dns-$${starter_location_01}"
    ddos_resource_group_name                       = "rg-hub-ddos-$${starter_location_01}"
    asc_export_resource_group_name                 = "rg-asc-export-$${starter_location_01}"
    service_health_alerts_resource_group_name      = "rg-service-health-alerts-$${starter_location_01}"

    # Resource names — management
    log_analytics_workspace_name            = "law-management-$${starter_location_01}"
    ddos_protection_plan_name               = "ddos-$${starter_location_01}"
    ama_user_assigned_managed_identity_name = "uami-management-ama-$${starter_location_01}"
    dcr_change_tracking_name                = "dcr-change-tracking"
    dcr_defender_sql_name                   = "dcr-defender-sql"
    dcr_vm_insights_name                    = "dcr-vm-insights"

    # Resource names — primary connectivity (names exist even for disabled resources)
    primary_virtual_network_name                                 = "vnet-hub-$${starter_location_01}"
    primary_firewall_name                                        = "fw-hub-$${starter_location_01}"
    primary_firewall_policy_name                                 = "fwp-hub-$${starter_location_01}"
    primary_firewall_public_ip_name                              = "pip-fw-hub-$${starter_location_01}"
    primary_firewall_management_public_ip_name                   = "pip-fw-hub-mgmt-$${starter_location_01}"
    primary_route_table_firewall_name                            = "rt-hub-fw-$${starter_location_01}"
    primary_route_table_user_subnets_name                        = "rt-hub-std-$${starter_location_01}"
    primary_virtual_network_gateway_express_route_name           = "vgw-hub-er-$${starter_location_01}"
    primary_virtual_network_gateway_express_route_public_ip_name = "pip-vgw-hub-er-$${starter_location_01}"
    primary_virtual_network_gateway_vpn_name                     = "vgw-hub-vpn-$${starter_location_01}"
    primary_virtual_network_gateway_vpn_public_ip_name_1         = "pip-vgw-hub-vpn-$${starter_location_01}-001"
    primary_virtual_network_gateway_vpn_public_ip_name_2         = "pip-vgw-hub-vpn-$${starter_location_01}-002"
    primary_private_dns_resolver_name                            = "pdr-hub-dns-$${starter_location_01}"
    primary_bastion_host_name                                    = "bas-hub-$${starter_location_01}"
    primary_bastion_host_public_ip_name                          = "pip-bastion-hub-$${starter_location_01}"

    # Resource names — secondary connectivity
    secondary_virtual_network_name                                 = "vnet-hub-$${starter_location_02}"
    secondary_firewall_name                                        = "fw-hub-$${starter_location_02}"
    secondary_firewall_policy_name                                 = "fwp-hub-$${starter_location_02}"
    secondary_firewall_public_ip_name                              = "pip-fw-hub-$${starter_location_02}"
    secondary_firewall_management_public_ip_name                   = "pip-fw-hub-mgmt-$${starter_location_02}"
    secondary_route_table_firewall_name                            = "rt-hub-fw-$${starter_location_02}"
    secondary_route_table_user_subnets_name                        = "rt-hub-std-$${starter_location_02}"
    secondary_virtual_network_gateway_express_route_name           = "vgw-hub-er-$${starter_location_02}"
    secondary_virtual_network_gateway_express_route_public_ip_name = "pip-vgw-hub-er-$${starter_location_02}"
    secondary_virtual_network_gateway_vpn_name                     = "vgw-hub-vpn-$${starter_location_02}"
    secondary_virtual_network_gateway_vpn_public_ip_name_1         = "pip-vgw-hub-vpn-$${starter_location_02}-001"
    secondary_virtual_network_gateway_vpn_public_ip_name_2         = "pip-vgw-hub-vpn-$${starter_location_02}-002"
    secondary_private_dns_resolver_name                            = "pdr-hub-dns-$${starter_location_02}"
    secondary_bastion_host_name                                    = "bas-hub-$${starter_location_02}"
    secondary_bastion_host_public_ip_name                          = "pip-bastion-hub-$${starter_location_02}"

    # Private DNS auto-registration zones
    primary_auto_registration_zone_name   = "$${starter_location_01}.azure.local"
    secondary_auto_registration_zone_name = "$${starter_location_02}.azure.local"

    # --- IP ranges — 172.16/172.17 (verified: all existing VNets are 10.x, no overlap) ---
    # Primary regional address space: 172.16.0.0/16
    primary_hub_address_space                          = "172.16.0.0/16"
    primary_hub_virtual_network_address_space          = "172.16.0.0/22"
    primary_firewall_subnet_address_prefix             = "172.16.0.0/26"
    primary_firewall_management_subnet_address_prefix  = "172.16.0.192/26"
    primary_bastion_subnet_address_prefix              = "172.16.0.64/26"
    primary_gateway_subnet_address_prefix              = "172.16.0.128/27"
    primary_private_dns_resolver_subnet_address_prefix = "172.16.0.160/28"
    # Secondary regional address space: 172.17.0.0/16
    secondary_hub_address_space                          = "172.17.0.0/16"
    secondary_hub_virtual_network_address_space          = "172.17.0.0/22"
    secondary_firewall_subnet_address_prefix             = "172.17.0.0/26"
    secondary_firewall_management_subnet_address_prefix  = "172.17.0.192/26"
    secondary_bastion_subnet_address_prefix              = "172.17.0.64/26"
    secondary_gateway_subnet_address_prefix              = "172.17.0.128/27"
    secondary_private_dns_resolver_subnet_address_prefix = "172.17.0.160/28"
  }
  resource_group_identifiers = {
    management_resource_group_id             = "/subscriptions/$${subscription_id_management}/resourcegroups/$${management_resource_group_name}"
    ddos_protection_plan_resource_group_id   = "/subscriptions/$${subscription_id_connectivity}/resourcegroups/$${ddos_resource_group_name}"
    primary_connectivity_resource_group_id   = "/subscriptions/$${subscription_id_connectivity}/resourceGroups/$${connectivity_hub_primary_resource_group_name}"
    secondary_connectivity_resource_group_id = "/subscriptions/$${subscription_id_connectivity}/resourceGroups/$${connectivity_hub_secondary_resource_group_name}"
    dns_resource_group_id                    = "/subscriptions/$${subscription_id_connectivity}/resourceGroups/$${dns_resource_group_name}"
  }
  resource_identifiers = {
    ama_change_tracking_data_collection_rule_id = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_change_tracking_name}"
    ama_mdfc_sql_data_collection_rule_id        = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_defender_sql_name}"
    ama_vm_insights_data_collection_rule_id     = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_vm_insights_name}"
    ama_user_assigned_managed_identity_id       = "$${management_resource_group_id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$${ama_user_assigned_managed_identity_name}"
    log_analytics_workspace_id                  = "$${management_resource_group_id}/providers/Microsoft.OperationalInsights/workspaces/$${log_analytics_workspace_name}"
    ddos_protection_plan_id                     = "$${ddos_protection_plan_resource_group_id}/providers/Microsoft.Network/ddosProtectionPlans/$${ddos_protection_plan_name}"
  }
}

# Chargeback tags. The four required tags are also enforced hierarchy-wide via
# policy (see main.tagging.tf).
tags = {
  deployed_by   = "terraform"
  project       = "platform-landing-zone"
  "cost-center" = "platform"
  environment   = "platform"
  owner         = "cloud@visium.ch"
}

# Central Log Analytics workspace + Sentinel onboarding live in Terraform.
# Sentinel data connectors are configured separately (module doesn't manage them).
management_resources_enabled = true

management_resource_settings = {
  location                     = "$${starter_location_01}"
  log_analytics_workspace_name = "$${log_analytics_workspace_name}"
  resource_group_name          = "$${management_resource_group_name}"
  sentinel_onboarding = {
    name = "default" # Azure only accepts the onboarding state name "default"
  }
  user_assigned_managed_identities = {
    ama = { name = "$${ama_user_assigned_managed_identity_name}" }
  }
  data_collection_rules = {
    change_tracking = { name = "$${dcr_change_tracking_name}" }
    defender_sql    = { name = "$${dcr_defender_sql_name}" }
    vm_insights     = { name = "$${dcr_vm_insights_name}" }
  }
}

management_groups_enabled = true

management_group_settings = {
  architecture_name  = "visium" # lib/architecture_definitions/visium.alz_architecture_definition.yaml
  location           = "$${starter_location_01}"
  parent_resource_id = "$${root_parent_management_group_id}"
  policy_default_values = {
    ama_change_tracking_data_collection_rule_id = "$${ama_change_tracking_data_collection_rule_id}"
    ama_mdfc_sql_data_collection_rule_id        = "$${ama_mdfc_sql_data_collection_rule_id}"
    ama_vm_insights_data_collection_rule_id     = "$${ama_vm_insights_data_collection_rule_id}"
    ama_user_assigned_managed_identity_id       = "$${ama_user_assigned_managed_identity_id}"
    ama_user_assigned_managed_identity_name     = "$${ama_user_assigned_managed_identity_name}"
    log_analytics_workspace_id                  = "$${log_analytics_workspace_id}"
    resource_group_name_service_health_alerts   = "$${service_health_alerts_resource_group_name}"
    resource_group_name_mdfc                    = "$${asc_export_resource_group_name}"
    resource_group_location                     = "$${starter_location_01}"
    email_security_contact                      = "$${defender_email_security_contact}"
  }
  # Subscription moves are done in the portal (the deploy SP's conditioned role
  # can't manage MG placement). See README-VISIUM.md.
  subscription_placement = {}
  # Keys are management-group ids from the architecture definition.
  # Deny policies start non-blocking (audit): add `enforcement_mode = "DoNotEnforce"`
  # per Deny-* assignment once the first plan lists them.
  policy_assignments_to_modify = {
    visium = {
      policy_assignments = {
        Deploy-MDFC-Config-H224 = {
          parameters = {
            enableAscForServers                         = "DeployIfNotExists"
            enableAscForServersVulnerabilityAssessments = "DeployIfNotExists"
            enableAscForSql                             = "DeployIfNotExists"
            enableAscForAppServices                     = "DeployIfNotExists"
            enableAscForStorage                         = "DeployIfNotExists"
            enableAscForContainers                      = "DeployIfNotExists"
            enableAscForKeyVault                        = "DeployIfNotExists"
            enableAscForSqlOnVm                         = "DeployIfNotExists"
            enableAscForArm                             = "DeployIfNotExists"
            enableAscForOssDb                           = "DeployIfNotExists"
            enableAscForCosmosDbs                       = "DeployIfNotExists"
            enableAscForCspm                            = "DeployIfNotExists"
          }
        }
      }
    }
    "visium-connectivity" = {
      policy_assignments = {
        Enable-DDoS-VNET = { creation_enabled = false }
      }
    }
    "visium-landing-zones" = {
      policy_assignments = {
        Enable-DDoS-VNET = { creation_enabled = false }
      }
    }
    "visium-corp" = {
      policy_assignments = {
        Deploy-Private-DNS-Zones = { creation_enabled = false }
      }
    }
  }
}

# --- Networking: multi-region hub & spoke, MINIMAL (no firewall/bastion/gateways/DDoS) ---
connectivity_type = "hub_and_spoke_vnet"

connectivity_resource_groups = {
  ddos = {
    name     = "$${ddos_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = "$${ddos_protection_plan_enabled}"
    }
  }
  vnet_primary = {
    name     = "$${connectivity_hub_primary_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = true
    }
  }
  vnet_secondary = {
    name     = "$${connectivity_hub_secondary_resource_group_name}"
    location = "$${starter_location_02}"
    settings = {
      enabled = true
    }
  }
  dns = {
    name     = "$${dns_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = "$${primary_private_dns_zones_enabled}"
    }
  }
}

hub_and_spoke_networks_settings = {
  enabled_resources = {
    ddos_protection_plan = "$${ddos_protection_plan_enabled}"
  }
  ddos_protection_plan = {
    name                = "$${ddos_protection_plan_name}"
    resource_group_name = "$${ddos_resource_group_name}"
    location            = "$${starter_location_01}"
  }
}

hub_virtual_networks = {
  primary = {
    location          = "$${starter_location_01}"
    default_parent_id = "$${primary_connectivity_resource_group_id}"
    enabled_resources = {
      firewall                              = "$${primary_firewall_enabled}"
      bastion                               = "$${primary_bastion_enabled}"
      virtual_network_gateway_express_route = "$${primary_virtual_network_gateway_express_route_enabled}"
      virtual_network_gateway_vpn           = "$${primary_virtual_network_gateway_vpn_enabled}"
      private_dns_zones                     = "$${primary_private_dns_zones_enabled}"
      private_dns_resolver                  = "$${primary_private_dns_resolver_enabled}"
    }
    hub_virtual_network = {
      name                          = "$${primary_virtual_network_name}"
      address_space                 = ["$${primary_hub_virtual_network_address_space}"]
      routing_address_space         = ["$${primary_hub_address_space}"]
      route_table_name_firewall     = "$${primary_route_table_firewall_name}"
      route_table_name_user_subnets = "$${primary_route_table_user_subnets_name}"
      subnets                       = {}
    }
    firewall = {
      subnet_address_prefix            = "$${primary_firewall_subnet_address_prefix}"
      management_subnet_address_prefix = "$${primary_firewall_management_subnet_address_prefix}"
      name                             = "$${primary_firewall_name}"
      sku_tier                         = "$${primary_firewall_sku_tier}"
      default_ip_configuration = {
        public_ip_config = {
          name = "$${primary_firewall_public_ip_name}"
        }
      }
      management_ip_enabled = "$${primary_firewall_management_ip_enabled}"
      management_ip_configuration = {
        public_ip_config = {
          name = "$${primary_firewall_management_public_ip_name}"
        }
      }
    }
    firewall_policy = {
      name = "$${primary_firewall_policy_name}"
      sku  = "$${primary_firewall_sku_tier}"
    }
    virtual_network_gateways = {
      subnet_address_prefix = "$${primary_gateway_subnet_address_prefix}"
      express_route = {
        name                                  = "$${primary_virtual_network_gateway_express_route_name}"
        hosted_on_behalf_of_public_ip_enabled = "$${primary_virtual_network_gateway_express_route_hobo_public_ip_enabled}"
        ip_configurations = {
          default = {
            public_ip = {
              name = "$${primary_virtual_network_gateway_express_route_public_ip_name}"
            }
          }
        }
      }
      vpn = {
        name = "$${primary_virtual_network_gateway_vpn_name}"
        ip_configurations = {
          active_active_1 = {
            public_ip = {
              name = "$${primary_virtual_network_gateway_vpn_public_ip_name_1}"
            }
          }
          active_active_2 = {
            public_ip = {
              name = "$${primary_virtual_network_gateway_vpn_public_ip_name_2}"
            }
          }
        }
      }
    }
    private_dns_zones = {
      parent_id = "$${dns_resource_group_id}"
      private_link_private_dns_zones_regex_filter = {
        enabled = false
      }
      auto_registration_zone_enabled = "$${primary_private_dns_auto_registration_zone_enabled}"
      auto_registration_zone_name    = "$${primary_auto_registration_zone_name}"
    }
    private_dns_resolver = {
      subnet_address_prefix = "$${primary_private_dns_resolver_subnet_address_prefix}"
      name                  = "$${primary_private_dns_resolver_name}"
    }
    bastion = {
      subnet_address_prefix = "$${primary_bastion_subnet_address_prefix}"
      name                  = "$${primary_bastion_host_name}"
      bastion_public_ip = {
        name = "$${primary_bastion_host_public_ip_name}"
      }
    }
  }
  secondary = {
    location          = "$${starter_location_02}"
    default_parent_id = "$${secondary_connectivity_resource_group_id}"
    enabled_resources = {
      firewall                              = "$${secondary_firewall_enabled}"
      bastion                               = "$${secondary_bastion_enabled}"
      virtual_network_gateway_express_route = "$${secondary_virtual_network_gateway_express_route_enabled}"
      virtual_network_gateway_vpn           = "$${secondary_virtual_network_gateway_vpn_enabled}"
      private_dns_zones                     = "$${secondary_private_dns_zones_enabled}"
      private_dns_resolver                  = "$${secondary_private_dns_resolver_enabled}"
    }
    hub_virtual_network = {
      name                          = "$${secondary_virtual_network_name}"
      address_space                 = ["$${secondary_hub_virtual_network_address_space}"]
      routing_address_space         = ["$${secondary_hub_address_space}"]
      route_table_name_firewall     = "$${secondary_route_table_firewall_name}"
      route_table_name_user_subnets = "$${secondary_route_table_user_subnets_name}"
      subnets                       = {}
    }
    firewall = {
      subnet_address_prefix            = "$${secondary_firewall_subnet_address_prefix}"
      management_subnet_address_prefix = "$${secondary_firewall_management_subnet_address_prefix}"
      name                             = "$${secondary_firewall_name}"
      sku_tier                         = "$${secondary_firewall_sku_tier}"
      default_ip_configuration = {
        public_ip_config = {
          name = "$${secondary_firewall_public_ip_name}"
        }
      }
      management_ip_enabled = "$${secondary_firewall_management_ip_enabled}"
      management_ip_configuration = {
        public_ip_config = {
          name = "$${secondary_firewall_management_public_ip_name}"
        }
      }
    }
    firewall_policy = {
      name = "$${secondary_firewall_policy_name}"
      sku  = "$${secondary_firewall_sku_tier}"
    }
    virtual_network_gateways = {
      subnet_address_prefix = "$${secondary_gateway_subnet_address_prefix}"
      express_route = {
        name                                  = "$${secondary_virtual_network_gateway_express_route_name}"
        hosted_on_behalf_of_public_ip_enabled = "$${secondary_virtual_network_gateway_express_route_hobo_public_ip_enabled}"
        ip_configurations = {
          default = {
            public_ip = {
              name = "$${secondary_virtual_network_gateway_express_route_public_ip_name}"
            }
          }
        }
      }
      vpn = {
        name = "$${secondary_virtual_network_gateway_vpn_name}"
        ip_configurations = {
          active_active_1 = {
            public_ip = {
              name = "$${secondary_virtual_network_gateway_vpn_public_ip_name_1}"
            }
          }
          active_active_2 = {
            public_ip = {
              name = "$${secondary_virtual_network_gateway_vpn_public_ip_name_2}"
            }
          }
        }
      }
    }
    private_dns_zones = {
      parent_id = "$${dns_resource_group_id}"
      private_link_private_dns_zones_regex_filter = {
        enabled = true
      }
      auto_registration_zone_enabled = "$${secondary_private_dns_auto_registration_zone_enabled}"
      auto_registration_zone_name    = "$${secondary_auto_registration_zone_name}"
    }
    private_dns_resolver = {
      subnet_address_prefix = "$${secondary_private_dns_resolver_subnet_address_prefix}"
      name                  = "$${secondary_private_dns_resolver_name}"
    }
    bastion = {
      subnet_address_prefix = "$${secondary_bastion_subnet_address_prefix}"
      name                  = "$${secondary_bastion_host_name}"
      bastion_public_ip = {
        name = "$${secondary_bastion_host_public_ip_name}"
      }
    }
  }
}

enable_telemetry = true
telemetry_additional_content = {
  deployed_by    = "alz-terraform-accelerator"
  correlation_id = "00000000-0000-0000-0000-000000000000"
}
