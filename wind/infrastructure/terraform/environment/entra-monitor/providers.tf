terraform {
  backend "azurerm" {
    storage_account_name = "sddccattle1773495465"
    container_name       = "tfstate"
    key                  = "entra-monitor.tfstate"
  }
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "azuread" {
  # Reads ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET from environment.
  # Source before running: source /mnt/stones/wind/secrets/terraform-sp.env
  # SP requires Policy.Read.All (Graph API application permission).
}

provider "external" {}
