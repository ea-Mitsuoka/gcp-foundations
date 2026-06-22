terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/monitoring/3_dashboards"
  }
}
