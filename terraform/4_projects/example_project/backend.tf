terraform {
  backend "gcs" {
    prefix = "projects/example_project"
  }
}