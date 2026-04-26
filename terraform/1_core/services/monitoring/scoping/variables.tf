variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

