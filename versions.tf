terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.62.1"
    }
  }
  backend "azurerm" {
    use_cli              = true                                    # Can also be set via `ARM_USE_CLI` environment variable.
    use_azuread_auth     = true                                    # Can also be set via `ARM_USE_AZUREAD` environment variable.
    use_oidc             = true # Crucial for the backend to work
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  storage_use_azuread = true
    # subscription_id = "f12e214d-46c6-49bf-a083-f89cf9c3179d"

}