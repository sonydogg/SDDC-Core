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