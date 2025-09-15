terraform {
  backend "gcs" {
    prefix = "core/services/logsink/google_project_service"
  }
}