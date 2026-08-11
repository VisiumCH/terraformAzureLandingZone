# Mandatory chargeback tags, enforced hierarchy-wide (non-blocking).
#
# Assigns the built-in "Inherit a tag from the resource group" (Modify) policy
# once per required tag at the `visium` intermediate root, so every resource
# inherits the tag from its resource group. Modify => adds tags WITHOUT blocking
# deployments (plan §3). Each assignment gets a system-assigned identity with the
# "Tag Contributor" role so it can remediate.

locals {
  required_tags = ["project", "cost-center", "environment", "owner"]
  visium_mg_id  = "/providers/Microsoft.Management/managementGroups/visium"
}

data "azurerm_policy_definition" "inherit_tag_from_rg" {
  display_name = "Inherit a tag from the resource group"
}

resource "azurerm_management_group_policy_assignment" "inherit_tag" {
  for_each = toset(local.required_tags)

  name                 = substr("inherit-tag-${replace(each.key, "-", "")}", 0, 24)
  display_name         = "Inherit '${each.key}' tag from resource group"
  management_group_id  = local.visium_mg_id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag_from_rg.id
  location             = var.starter_locations[0]

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  depends_on = [module.management_groups]
}

# The Modify effect needs the assignment identity to be able to write tags.
resource "azurerm_role_assignment" "inherit_tag_remediation" {
  for_each = azurerm_management_group_policy_assignment.inherit_tag

  scope                = local.visium_mg_id
  role_definition_name = "Tag Contributor"
  principal_id         = each.value.identity[0].principal_id
}
