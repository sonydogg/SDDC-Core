variable "subscription_id" {
  type        = string
  description = "The Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "The Azure Tenant ID"
}

variable "resource_group_name" {
  type        = string
  default     = "SDDC"
  description = "Primary RG for SDDC management resources"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "The Azure region for deployment"
}

variable "client_id" {
  type        = string
  description = "The Service Principal App ID"
}

variable "client_secret" {
  type        = string
  description = "The Service Principal Password"
  sensitive   = true
}
variable "storage_account" {
  type        = string
  default     = "sddc"
  description = "Storage account for Terraform state"
}

variable "home_public_ip" {
  type        = string
  description = "Current home public IP for TrueNAS storage account firewall rule — update when IP changes after extended power loss"
}