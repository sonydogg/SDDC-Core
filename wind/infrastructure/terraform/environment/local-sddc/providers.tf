terraform {
    backend "azurerm" {
    storage_account_name  = "sddccattle1773495465"
    container_name        = "tfstate"
    key                   = "local-sddc.tfstate" # Different for each folder
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.6"
    }
  }
}
provider "libvirt" {
  uri = "qemu:///system"
  # Configuration options
}