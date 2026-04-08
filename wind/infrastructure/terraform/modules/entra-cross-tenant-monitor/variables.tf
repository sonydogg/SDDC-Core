variable "snapshot_label" {
  description = "Human-readable label stamped into the snapshot (e.g. 'approved-2026-04-07'). Changing this triggers a plan diff, making approvals traceable in state history."
  type        = string
  default     = "baseline"
}
