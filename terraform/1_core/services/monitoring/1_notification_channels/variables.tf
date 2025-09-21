variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "notifications_csv_path" {
  type        = string
  description = "通知チャネルの定義を記載したCSVファイルのパス。"
}
