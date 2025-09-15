terraform {
  backend "gcs" {
    prefix = "core/services/logsink/log_based_metrics"
  }
}