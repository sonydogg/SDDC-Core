variable "snapshot_label" {
  description = "Label for the current approved snapshot. Use a datestamp when re-baselining (e.g. 'approved-2026-04-07')."
  type        = string
  default     = "baseline"
}
