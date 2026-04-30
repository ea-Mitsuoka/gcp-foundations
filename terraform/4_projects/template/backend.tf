terraform {
  backend "gcs" {
    prefix = "projects/template"
  }
}
