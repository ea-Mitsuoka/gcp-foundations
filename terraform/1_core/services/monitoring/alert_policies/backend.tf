terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/alert_policies"
  }
}
