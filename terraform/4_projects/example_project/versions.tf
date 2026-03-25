terraform {
  # "~>" を使い、意図しないメジャー/マイナーアップデートを防ぎます
  required_version = "~> 1.12.2"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.48.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.48.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.2.2"
    }
  }
}
