# The "Update Manager" Policy
# This tells Azure: "Any Arc server in this RG must be tracked by Update Manager"
resource "azurerm_resource_policy_assignment" "enable_update_manager" {
  name                 = "enable-azure-update-manager"
  resource_id          = "/subscriptions/${var.subscription_id}/resourceGroups/SDDC"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${var.subscription_id}/${var.resource_group_name}" 
  
  description          = "Ensures Update Management is enabled for all Arc-enabled servers"
  display_name         = "Configure Azure Update Manager for Arc Servers"
}