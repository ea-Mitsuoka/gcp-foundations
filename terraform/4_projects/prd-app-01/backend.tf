terraform {
  backend "gcs" {
    prefix = "projects/prd-app-01"
  }
}