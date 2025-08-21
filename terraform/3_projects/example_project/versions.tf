terraform {
  # "~>" を使い、意図しないメジャー/マイナーアップデートを防ぎます
  required_version = "~> 1.12.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}