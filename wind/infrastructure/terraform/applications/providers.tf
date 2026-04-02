terraform {
    backend "azurerm" {
        resource_group_name  = "SDDC"
        storage_account_name = "${var.storage_account}"
        container_name       = "tfstate"
        key                  = "application.fstate" # Different for each folder
    }    
    required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}
provider "grafana_sso_settings"  {
    oauth2_settings {
        client_authentication = "${var.client_authentication}"
    }
}
provider "azuread" {
  
}