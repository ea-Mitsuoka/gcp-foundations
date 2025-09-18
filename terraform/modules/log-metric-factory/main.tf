resource "google_logging_metric" "this" {
  project = var.project_id
  name    = var.metric_name
  filter  = var.metric_filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}
