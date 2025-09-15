terraform {
  backend "gcs" {
    prefix = "core/base/monitoring"
  }
}