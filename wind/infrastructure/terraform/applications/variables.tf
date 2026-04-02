variable "client_authentication" {
  type        = string
  description = "Client authentication method for Azure AD SSO (e.g., 'client_secret' or 'managed_identity')"
  default     = "client_secret"
}
variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  default     = "GrafanaAdminPassword123!"  
}
variable "grafana_url" {
  
}
variable "tenant_id" {
  type = string
  default = "tenant id"
}