# Visium greenfield platform landing zone — inputs for the ALZ accelerator.
# Tokens like $${starter_location_01} are accelerator built-in replacements.

starter_locations = ["switzerlandnorth"]

# The `visium` intermediate root is created directly under the TENANT ROOT
# (tenant-root management-group id == the Entra tenant id).
root_parent_management_group_id = "b7418ead-a445-4708-a309-951ab14852eb"

# `connectivity`/`identity` are reserved; pointed at Management so the module's
# providers resolve while connectivity_type = "none" (no resources deployed there).
subscription_ids = {
  management   = "8745729a-505a-4910-aaaf-d53b9cdc8883"
  connectivity = "8745729a-505a-4910-aaaf-d53b9cdc8883"
  identity     = "8745729a-505a-4910-aaaf-d53b9cdc8883"
}

custom_replacements = {
  names = {
    defender_email_security_contact = "cloud@visium.ch"

    management_resource_group_name            = "rg-management-$${starter_location_01}"
    asc_export_resource_group_name            = "rg-asc-export-$${starter_location_01}"
    service_health_alerts_resource_group_name = "rg-service-health-alerts-$${starter_location_01}"

    log_analytics_workspace_name            = "law-management-$${starter_location_01}"
    ama_user_assigned_managed_identity_name = "uami-management-ama-$${starter_location_01}"
    dcr_change_tracking_name                = "dcr-change-tracking"
    dcr_defender_sql_name                   = "dcr-defender-sql"
    dcr_vm_insights_name                    = "dcr-vm-insights"
  }
  resource_group_identifiers = {
    management_resource_group_id = "/subscriptions/$${subscription_id_management}/resourcegroups/$${management_resource_group_name}"
  }
  resource_identifiers = {
    ama_change_tracking_data_collection_rule_id = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_change_tracking_name}"
    ama_mdfc_sql_data_collection_rule_id        = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_defender_sql_name}"
    ama_vm_insights_data_collection_rule_id     = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_vm_insights_name}"
    ama_user_assigned_managed_identity_id       = "$${management_resource_group_id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$${ama_user_assigned_managed_identity_name}"
    log_analytics_workspace_id                  = "$${management_resource_group_id}/providers/Microsoft.OperationalInsights/workspaces/$${log_analytics_workspace_name}"
  }
}

# Chargeback tags are also enforced hierarchy-wide via policy (see root_custom archetype).
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
  # Core build places only the Management sub. The 14 existing subs are migrated
  # from mg-02 into corp/online later, one at a time; the credits sub lands in online.
  # Subscription moves are deferred: moving a sub into an MG needs UNCONSTRAINED
  # roleAssignments write/delete on the sub, which the deploy SP's conditioned
  # role assignments don't grant. Move sub-visium-management -> visium-management
  # and sub-visium-online -> visium-online manually (or re-add here once the SP
  # has unconditioned User Access Administrator / Owner). Deferring does not
  # affect the LAW/Sentinel that deploy into the management sub.
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

connectivity_type = "none"

enable_telemetry = true
telemetry_additional_content = {
  deployed_by    = "alz-terraform-accelerator"
  correlation_id = "00000000-0000-0000-0000-000000000000"
}
