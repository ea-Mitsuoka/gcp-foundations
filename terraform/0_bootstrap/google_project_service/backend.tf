terraform {
  backend "gcs" {
    bucket = ""
    prefix = "bootstrap/google_project_service"
  }
}