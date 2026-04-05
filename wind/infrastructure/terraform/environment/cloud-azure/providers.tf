terraform {
  backend "azurerm" {
    storage_account_name = "sddccattle1773495465"
    container_name       = "tfstate"
    key                  = "cloud-azure.tfstate" # Different for each folder
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
  }
}
provider "azurerm" {
  # This block is mandatory for the Azure provider
  features {}
}
provider "azuread" {
  # This block is mandatory for the Azure AD provider
}
