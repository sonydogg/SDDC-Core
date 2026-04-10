data "azurerm_arc_machine" "intel_01" {
  name                = "mini-me-intel-01"
  resource_group_name = var.resource_group_name
}

# The "Ear" - Where logs and metrics will live

resource "azurerm_log_analytics_workspace" "sddc_logs" {
  name                = "sddc-logs"
  location            = var.location # Or your preferred region
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018" # The "Pay-as-you-go" / Free Tier compatible SKU
  retention_in_days   = 30
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

# Periodic Assessment Policy
# Triggers assessment scans (~every 24h) so Update Manager knows what patches
# are pending before the maintenance window opens. Without this, compliance
# visibility is blind between installation windows.
resource "azurerm_resource_group_policy_assignment" "periodic_assessment" {
  name                 = "sddc-periodic-assessment"
  resource_group_id    = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15"

  description  = "Enables periodic checking for missing system updates on Arc-enabled servers"
  display_name = "Periodic Assessment for Arc Servers"
  location     = var.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "periodic_assessment_remediation_role" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.periodic_assessment.identity[0].principal_id
}