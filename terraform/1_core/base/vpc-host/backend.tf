terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/base/vpc-host"
  }
}
