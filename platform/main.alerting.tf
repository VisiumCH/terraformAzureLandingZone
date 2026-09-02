# Infra push-notification alerting path 
# Azure Monitor Action Group -> Logic App -> Slack (#visium-infra-alerts).
# An Action Group webhook receiver cannot post to Slack directly (it emits the
# Azure alert schema; a Slack incoming webhook only renders {"text": ...}), so a
# Logic App transforms the alert into a Slack message. The Action Group here is
# the REUSABLE target that the other alert issues point at.
# Lives in the management subscription.

resource "azurerm_resource_group" "alerting" {
  provider = azurerm.management

  name     = "rg-alerting-prod"
  location = var.starter_locations[0]
  tags     = var.tags
}

resource "azurerm_logic_app_workflow" "slack_alerts" {
  provider = azurerm.management

  name                = "logic-slack-infra-alerts"
  location            = azurerm_resource_group.alerting.location
  resource_group_name = azurerm_resource_group.alerting.name
  tags                = var.tags
}

# HTTP trigger the Action Group calls. Schema is permissive (any object) so it
# accepts the common alert schema without a rigid contract.
resource "azurerm_logic_app_trigger_http_request" "slack_alerts" {
  name         = "manual"
  logic_app_id = azurerm_logic_app_workflow.slack_alerts.id

  schema = jsonencode({
    type       = "object"
    properties = {}
  })
}

# POST the formatted message to the Slack incoming webhook. The @{...} tokens are
# Logic App runtime expressions (evaluated by Azure, not Terraform) that pull
# fields out of the common alert schema payload.
resource "azurerm_logic_app_action_http" "slack_post" {
  name         = "post-to-slack"
  logic_app_id = azurerm_logic_app_workflow.slack_alerts.id

  method = "POST"
  uri    = var.slack_webhook_url

  headers = {
    "Content-Type" = "application/json"
  }

  # Slack Block Kit message. Generic across all alert rules that use this Action
  # Group: the header is the rule name; the body prefers a rich "Details" string
  # supplied as an alert dimension (see the public-resource rule) and falls back
  # to the alert description for rules that don't set one. 
  body = jsonencode({
    text = "@{concat('Alert: ', triggerBody()?['data']?['essentials']?['alertRule'])}"
    blocks = [
      {
        type = "header"
        text = {
          type  = "plain_text"
          emoji = true
          text  = "@{concat(':rotating_light: ', triggerBody()?['data']?['essentials']?['alertRule'])}"
        }
      },
      {
        type = "section"
        text = {
          type = "mrkdwn"
          text = "@{coalesce(first(coalesce(first(coalesce(triggerBody()?['data']?['alertContext']?['condition']?['allOf'], json('[]')))?['dimensions'], json('[]')))?['value'], triggerBody()?['data']?['essentials']?['description'], 'An alert fired.')}"
        }
      },
      {
        type = "context"
        elements = [
          {
            type = "mrkdwn"
            text = "@{concat(':triangular_flag_on_post: Severity ', coalesce(triggerBody()?['data']?['essentials']?['severity'], '-'), '   ·   ', coalesce(triggerBody()?['data']?['essentials']?['monitorCondition'], '-'), '   ·   fired ', coalesce(triggerBody()?['data']?['essentials']?['firedDateTime'], '-'), ' UTC')}"
          }
        ]
      }
    ]
  })
}

# The reusable Action Group. Point every alert rule at this.
resource "azurerm_monitor_action_group" "infra_alerts" {
  provider = azurerm.management

  name                = "ag-infra-alerts"
  resource_group_name = azurerm_resource_group.alerting.name
  short_name          = "infraalert"
  tags                = var.tags

  logic_app_receiver {
    name                    = "slack"
    resource_id             = azurerm_logic_app_workflow.slack_alerts.id
    callback_url            = azurerm_logic_app_trigger_http_request.slack_alerts.callback_url
    use_common_alert_schema = true
  }
}

output "infra_alerts_action_group_id" {
  description = "Resource ID of the reusable infra-alerts Action Group (target for alert rules 2.2/2.4/2.5)."
  value       = azurerm_monitor_action_group.infra_alerts.id
}

# ---------------------------------------------------------------------------
#
# A timer-driven Logic App queries Azure Resource Graph every 15 min for
# resources that were created and are actually risky. It deliberately ignores the
# intentional/expected public surface (gateway/LB/NAT public IPs, and the
# ubiquitous storage "public network access") so Slack only pings on the
# surprising cases:
#   * a public IP attached directly to a VM NIC  (someone exposed a VM), and
#   * a storage account with anonymous blob (public) access enabled.
#
# Resource Graph is used (not the Activity Log) because both signals are resource
# PROPERTIES the Activity Log can't see, and its change feed carries who
# (changedBy), when, and how (clientType, e.g. "Azure Portal"). The Logic App
# posts a Block Kit message straight to Slack (the reusable ag-infra-alerts group
# above stays the target for metric/log alerts).
#
# To broaden coverage later, add cases to the `reason` expression in the query.
# ---------------------------------------------------------------------------

locals {
  public_resource_watch_query = <<-KQL
    resourcechanges
    | extend ct = tostring(properties.changeType),
             rid = tolower(tostring(properties.targetResourceId)),
             ts = todatetime(properties.changeAttributes.timestamp),
             who = tostring(properties.changeAttributes.changedBy),
             whoType = tostring(properties.changeAttributes.changedByType),
             client = tostring(properties.changeAttributes.clientType)
    | where ts > ago(18m) and ct == 'Create'
    | where rid has 'publicipaddresses' or rid has 'storageaccounts'
    | project rid, ts, who, whoType, client
    | join kind=inner (
        resources
        | extend rid = tolower(id)
        | project rid, name, type, resourceGroup, subscriptionId,
                  ipcfg = tostring(properties.ipConfiguration.id),
                  blob = tostring(properties.allowBlobPublicAccess)
      ) on rid
    | extend reason = case(
        type =~ 'microsoft.network/publicipaddresses' and ipcfg has 'networkInterfaces', 'Public IP attached directly to a VM NIC',
        type =~ 'microsoft.storage/storageaccounts' and blob == 'true', 'Storage account with anonymous blob (public) access enabled',
        '')
    | where reason != ''
    | extend whenUtc = format_datetime(ts, 'yyyy-MM-dd HH:mm')
    | project name, type, resourceGroup, subscriptionId, reason, whenUtc, who, whoType, client
  KQL
}

resource "azapi_resource" "public_resource_watch" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "logic-public-resource-watch"
  location  = azurerm_resource_group.alerting.location
  parent_id = azurerm_resource_group.alerting.id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
        contentVersion = "1.0.0.0"
        parameters = {
          slackWebhookUrl = { type = "securestring" }
        }
        triggers = {
          Every_15_min = {
            type = "Recurrence"
            recurrence = {
              frequency = "Minute"
              interval  = 15
            }
          }
        }
        actions = {
          Run_ARG_query = {
            type = "Http"
            inputs = {
              method  = "POST"
              uri     = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
              headers = { "Content-Type" = "application/json" }
              body = {
                managementGroups = ["visium"]
                query            = local.public_resource_watch_query
                options          = { resultFormat = "objectArray" }
              }
              authentication = {
                type     = "ManagedServiceIdentity"
                audience = "https://management.azure.com/"
              }
            }
          }
          For_each_finding = {
            type    = "Foreach"
            foreach = "@body('Run_ARG_query')?['data']"
            runAfter = {
              Run_ARG_query = ["Succeeded"]
            }
            actions = {
              Post_to_Slack = {
                type = "Http"
                inputs = {
                  method  = "POST"
                  uri     = "@parameters('slackWebhookUrl')"
                  headers = { "Content-Type" = "application/json" }
                  body = {
                    text = "Public resource created and needs review"
                    blocks = [
                      {
                        type = "header"
                        text = { type = "plain_text", emoji = true, text = ":warning: Public resource created — review" }
                      },
                      {
                        type = "section"
                        text = { type = "mrkdwn", text = "*@{items('For_each_finding')?['reason']}*" }
                      },
                      {
                        type = "section"
                        fields = [
                          { type = "mrkdwn", text = "*:package: Resource*\n`@{items('For_each_finding')?['name']}`" },
                          { type = "mrkdwn", text = "*:file_folder: Resource group*\n@{items('For_each_finding')?['resourceGroup']}" },
                          { type = "mrkdwn", text = "*:bust_in_silhouette: Who*\n@{items('For_each_finding')?['who']} (@{items('For_each_finding')?['whoType']})" },
                          { type = "mrkdwn", text = "*:clock3: When (UTC)*\n@{items('For_each_finding')?['whenUtc']}" },
                          { type = "mrkdwn", text = "*:key: Subscription*\n@{items('For_each_finding')?['subscriptionId']}" },
                          { type = "mrkdwn", text = "*:computer: Via*\n@{items('For_each_finding')?['client']}" },
                        ]
                      },
                      {
                        type     = "context"
                        elements = [{ type = "mrkdwn", text = ":globe_with_meridians: @{items('For_each_finding')?['type']}" }]
                      },
                    ]
                  }
                }
              }
            }
          }
        }
      }
      parameters = {
        slackWebhookUrl = { value = var.slack_webhook_url }
      }
    }
  }

  schema_validation_enabled = false
}

# The watcher's managed identity needs to read the whole tree via Resource Graph.
resource "azurerm_role_assignment" "public_resource_watch_reader" {
  provider = azurerm.management

  scope                = "/providers/Microsoft.Management/managementGroups/visium"
  role_definition_name = "Reader"
  principal_id         = azapi_resource.public_resource_watch.identity[0].principal_id
}
