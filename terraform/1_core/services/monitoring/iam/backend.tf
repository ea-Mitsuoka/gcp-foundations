terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/monitoring/iam"
  }
}