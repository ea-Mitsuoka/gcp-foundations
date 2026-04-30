terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/monitoring/google_project_service"
  }
}