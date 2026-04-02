resource "grafana_sso_settings" "azuread_sso_settings" {
  provider_name = "azuread"
  oauth2_settings {
    name                          = "Entra ID"
    auth_url                      = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize"
    token_url                     = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
    client_id                     = "APPLICATION_ID"
    client_secret                 = "CLIENT_SECRET"
    allow_sign_up                 = true
    auto_login                    = false
    scopes                        = "openid email profile"
    allowed_organizations         = "${var.tenant_id}"
    role_attribute_strict         = false
    allow_assign_grafana_admin    = false
    skip_org_role_sync            = false
    use_pkce                      = true
    custom = {
      domain_hint = "contoso.com"
      force_use_graph_api = "true"
    }
  }
}