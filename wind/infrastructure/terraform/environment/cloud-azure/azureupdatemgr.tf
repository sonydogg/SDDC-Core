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