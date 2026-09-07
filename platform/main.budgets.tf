# 2.5 — Per-subscription monthly budgets with threshold alerts to Slack.
#
# Each subscription in the visium tree gets a monthly consumption budget. At
# 50 / 80 / 100% of actual spend, plus 100% of forecast (early warning), it
# notifies the reusable ag-infra-alerts Action Group, which the Logic App shim
# posts to #visium-infra-alerts. Budget notifications reach the Action Group in
# the common alert schema (use_common_alert_schema = true on the receiver), so
# no Logic App change is needed.
#
# Alerting only — a budget caps nothing and stops no spend; it just makes spend
# visible. The deploy SP's Management-Group Contributor at the root lets it write
# budgets on every subscription in the tree.

variable "default_monthly_budget_amount" {
  type        = number
  default     = 500
  description = "Default monthly budget per subscription, in the billing currency, used when a subscription has no explicit amount override."
}

variable "budget_start_date" {
  type        = string
  default     = "2026-09-01T00:00:00Z"
  description = "Budget period start. Must be the first day of a month (RFC3339, UTC)."
}

variable "subscription_budgets" {
  description = "Subscriptions to put a monthly budget on. Key = friendly name; subscription_id = the GUID; amount (optional) overrides default_monthly_budget_amount."
  type = map(object({
    subscription_id = string
    amount          = optional(number)
  }))
  default = {}
}

resource "azurerm_consumption_budget_subscription" "sub" {
  for_each = var.subscription_budgets

  name            = "budget-monthly-visium"
  subscription_id = "/subscriptions/${each.value.subscription_id}"

  amount     = coalesce(each.value.amount, var.default_monthly_budget_amount)
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  # Actual-spend thresholds.
  dynamic "notification" {
    for_each = toset([50, 80, 100])
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Actual"
      contact_groups = [azurerm_monitor_action_group.infra_alerts.id]
    }
  }

  # Early warning: forecast to exceed 100% of the budget this month.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_groups = [azurerm_monitor_action_group.infra_alerts.id]
  }
}
