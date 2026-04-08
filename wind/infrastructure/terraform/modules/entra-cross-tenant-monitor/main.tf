# Reads the live cross-tenant default policy via Graph API.
# The external provider requires a script that returns a flat string map (all values must be strings).
data "external" "cross_tenant_default" {
  program = ["bash", "${path.module}/scripts/get-default.sh"]
}

# Reads all per-partner cross-tenant configurations.
data "external" "cross_tenant_partners" {
  program = ["bash", "${path.module}/scripts/get-partners.sh"]
}

# Snapshot — stores the last-approved state in Terraform remote state.
# terraform plan surfaces a diff here whenever live settings have changed since last apply.
# To accept/baseline a change: review the diff, then terraform apply.
resource "terraform_data" "snapshot" {
  input = {
    label          = var.snapshot_label
    default_policy = data.external.cross_tenant_default.result.raw_json
    # Structured fields produce clean plan diffs — adding/removing an org shows
    # exactly which tenantId changed rather than a raw JSON blob comparison.
    partner_tenant_ids = data.external.cross_tenant_partners.result.tenant_ids
    partner_summary    = data.external.cross_tenant_partners.result.summary
  }
}
