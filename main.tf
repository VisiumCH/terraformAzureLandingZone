module "avm-res-resources-resourcegroup" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.2"
  location = var.primary_location
  name     = "rg-${var.application_name}-${var.primary_location}"
}

module "avm-res-storage-storageaccount" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.7"
  location            = var.primary_location
  name                = "st${var.application_name}02"
  resource_group_name = module.avm-res-resources-resourcegroup.name
  containers          = var.containers
}

module "avm-res-operationalinsights-workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"
  location            = var.primary_location
  name                = "law-${var.application_name}-${var.primary_location}"
  resource_group_name = module.avm-res-resources-resourcegroup.name
}

module "avm-ptn-aiml-ai-foundry" {
  source                     = "Azure/avm-ptn-aiml-ai-foundry/azurerm"
  version                    = "0.10.1"
  location                   = var.primary_location
  resource_group_resource_id = module.avm-res-resources-resourcegroup.resource_id
  base_name                  = var.application_name
}