resource "grafana_data_source" "azure_monitor" {
  type = "grafana-azure-monitor-datasource"
  name = "Azure Monitor"

  json_data_encoded = jsonencode({
    azureAuthType  = "clientsecret"
    cloudName      = "azuremonitor"
    tenantId       = "<TENANT_ID>"
    clientId       = "<CLIENT_ID>"
    subscriptionId = "<SUBSCRIPTION_ID>"
  })

  secure_json_data_encoded = jsonencode({
    clientSecret = "<CLIENT_SECRET>"
  })
}