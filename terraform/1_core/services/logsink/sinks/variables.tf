variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "bq_dataset_delete_contents_on_destroy" {
  type        = bool
  description = "If set to true, deletes all tables in the dataset when the dataset is destroyed."
  default     = false
}

variable "gcs_log_retention_days" {
  type        = number
  description = "The number of days to retain logs in the GCS bucket."
  default     = 365
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}
