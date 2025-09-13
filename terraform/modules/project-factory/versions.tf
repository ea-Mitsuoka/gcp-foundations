terraform {
  # required_versionはルートモジュールで定義する
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.48.0"
    }
  }
}