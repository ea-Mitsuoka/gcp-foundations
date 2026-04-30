terraform {
  backend "gcs" {
    bucket = ""
    prefix = "projects/example_project"
  }
}