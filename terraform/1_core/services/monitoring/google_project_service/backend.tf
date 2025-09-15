terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/google_project_service"
  }
}