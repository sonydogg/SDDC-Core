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
  arc_machine_id       = data.azurerm_arc_machine.intel_01.id
  location             = var.location
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
}