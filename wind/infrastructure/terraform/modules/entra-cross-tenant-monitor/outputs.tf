# Decoded live state — useful for terraform output inspection and downstream consumers.

output "default_policy" {
  description = "Current live cross-tenant default policy as a structured object"
  value       = jsondecode(data.external.cross_tenant_default.result.raw_json)
}

output "partners" {
  description = "Current live partner configurations as a structured object (full detail)"
  value       = jsondecode(data.external.cross_tenant_partners.result.raw_json)
}

output "partner_organizations" {
  description = "Summarized list of configured orgs: tenantId, inbound/outbound B2B access type, MFA trust"
  value       = jsondecode(data.external.cross_tenant_partners.result.summary)
}

output "partner_tenant_ids" {
  description = "Sorted list of configured partner tenant IDs — watch this for additions/removals"
  value       = jsondecode(data.external.cross_tenant_partners.result.tenant_ids)
}

output "partner_count" {
  description = "Number of explicitly configured partner tenants"
  value       = tonumber(data.external.cross_tenant_partners.result.count)
}

output "allow_invites_from" {
  description = "Who can send B2B invitations (adminsAndGuestInviters | adminsAndAllMembers | allUsers | none)"
  value       = data.external.cross_tenant_default.result.allow_invites_from
}

# Snapshot metadata — reflects what was last applied (approved), not live state.
output "last_snapshot_label" {
  description = "Label from the most recently applied snapshot"
  value       = terraform_data.snapshot.output.label
}
