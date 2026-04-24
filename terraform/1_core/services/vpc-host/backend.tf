terraform {
  backend "gcs" {
    prefix = "core/services/vpc-host"
  }
}
