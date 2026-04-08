output "allow_invites_from" {
  description = "Current B2B invite permission level"
  value       = module.cross_tenant_monitor.allow_invites_from
}

output "partner_count" {
  description = "Number of explicitly configured partner tenants"
  value       = module.cross_tenant_monitor.partner_count
}

output "default_policy" {
  description = "Full default cross-tenant access policy"
  value       = module.cross_tenant_monitor.default_policy
}

output "partners" {
  description = "All partner-specific cross-tenant configurations"
  value       = module.cross_tenant_monitor.partners
}

output "last_snapshot_label" {
  description = "Label from the most recently approved snapshot"
  value       = module.cross_tenant_monitor.last_snapshot_label
}
