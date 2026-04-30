terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/base/monitoring"
  }
}