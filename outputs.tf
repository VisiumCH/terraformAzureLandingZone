output "resource_group_name" {
  description = "The name of the deployed resource group."
  value       = module.avm-res-resources-resourcegroup.name
}

output "storage_account_name" {
  description = "The name of the deployed storage account."
  value       = module.avm-res-storage-storageaccount.name
}

output "log_analytics_workspace_id" {
  description = "The resource ID of the deployed Log Analytics Workspace."
  value       = module.avm-res-operationalinsights-workspace.resource_id
}

output "ai_foundry_project_id" {
  description = "The resource ID of the deployed AI Foundry project."
  value       = module.avm-ptn-aiml-ai-foundry.ai_foundry_project_id
}

output "ai_foundry_id" {
  description = "The resource ID of the deployed AI Foundry."
  value       = module.avm-ptn-aiml-ai-foundry.ai_foundry_id
}
