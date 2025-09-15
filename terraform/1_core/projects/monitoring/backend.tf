terraform {
  backend "gcs" {
    prefix = "core/projects/monitoring"
  }
}