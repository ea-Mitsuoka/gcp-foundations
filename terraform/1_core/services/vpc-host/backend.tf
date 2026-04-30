terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/vpc-host"
  }
}
