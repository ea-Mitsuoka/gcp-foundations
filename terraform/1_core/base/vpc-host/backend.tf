terraform {
  backend "gcs" {
    prefix = "core/base/vpc-host"
  }
}
