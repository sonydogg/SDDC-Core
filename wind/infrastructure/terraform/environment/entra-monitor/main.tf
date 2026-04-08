module "cross_tenant_monitor" {
  source = "../../modules/entra-cross-tenant-monitor"

  # Update this label when intentionally approving a change — creates a traceable
  # record in state history of who approved what and when.
  snapshot_label = var.snapshot_label
}
