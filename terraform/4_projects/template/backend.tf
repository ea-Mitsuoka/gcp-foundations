terraform {
  backend "gcs" {
    bucket = ""
    prefix = "projects/template"
  }
}
