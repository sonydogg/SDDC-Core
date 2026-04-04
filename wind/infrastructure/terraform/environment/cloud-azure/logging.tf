# The "Ear" - Where logs and metrics will live
resource "azurerm_log_analytics_workspace" "sddc_logs" {
  name                = "sddc-logs"
  location            = "${var.location}" # Or your preferred region
  resource_group_name = "SDDC"
  sku                 = "PerGB2018" # The "Pay-as-you-go" / Free Tier compatible SKU
  retention_in_days   = 30
}

# Azure Monitor Workspace
resource "azurerm_monitor_workspace" "sddc_monitor" {
  name                = "sddc-monitor"
  location            = var.location
  resource_group_name = var.resource_group_name
}