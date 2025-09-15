terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/scoping"
  }
}