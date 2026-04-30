terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/logsink/sinks"
  }
}