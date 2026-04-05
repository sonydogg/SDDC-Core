data "azurerm_arc_machine" "intel_01" {
  name                = "mini-me-intel-01"
  resource_group_name = var.resource_group_name
}# The "Ear" - Where logs and metrics will live


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
# Required because this arc server was onboarded manually before the DCR was created. If we don't do this, the AMA agent won't have permissions to send data to the Log Analytics workspace.

resource "azurerm_role_assignment" "arc_metrics_publisher" {
  scope                = azurerm_log_analytics_workspace.sddc_logs.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = data.azurerm_arc_machine.intel_01.identity[0].principal_id
}

# 1. Install the AMA Extension on the Intel Mini
resource "azurerm_arc_machine_extension" "ama" {
  name                 = "AzureMonitorLinuxAgent"
  arc_machine_id       = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.HybridCompute/machines/mini-me-intel-01"
  location             = var.location
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
}

# The "Update Manager" Policy
# This tells Azure: "Any Arc server in this RG must be tracked by Update Manager"
resource "azurerm_resource_group_policy_assignment" "enable_update_manager" {
  name                 = "enable-azure-update-manager"
  resource_group_id    = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/bfea026e-043f-4ff4-9d1b-bf301ca7ff46" 
  
  description          = "Ensures Update Management is enabled for all Arc-enabled servers"
  display_name         = "Configure Azure Update Manager for Arc Servers"
  location             = var.location

  identity {
  type = "SystemAssigned"
}
parameters = jsonencode({
    "assessmentMode" = {
      "value" = "AutomaticByPlatform"
    }
  })
} 

resource "azurerm_role_assignment" "policy_remediation_role" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.enable_update_manager.identity[0].principal_id
}