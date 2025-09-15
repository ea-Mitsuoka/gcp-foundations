terraform {
  backend "gcs" {
    prefix = "core/services/logsink/sinks"
  }
}