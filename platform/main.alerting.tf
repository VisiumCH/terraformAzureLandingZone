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

  body = jsonencode({
    text = join("\n", [
      ":rotating_light: *Azure Alert:* @{triggerBody()?['data']?['essentials']?['alertRule']}",
      "*Severity:* @{triggerBody()?['data']?['essentials']?['severity']}",
      "*Condition:* @{triggerBody()?['data']?['essentials']?['monitorCondition']}",
      "*Fired (UTC):* @{triggerBody()?['data']?['essentials']?['firedDateTime']}",
      "*Description:* @{triggerBody()?['data']?['essentials']?['description']}",
    ])
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
