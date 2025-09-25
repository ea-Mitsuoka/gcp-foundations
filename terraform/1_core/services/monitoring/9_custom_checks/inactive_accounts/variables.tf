variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "gcp_region" {
  type        = string
  description = "リソースを作成するデフォルトリージョン。"
  default     = "asia-northeast1"
}

variable "function_source_object" {
  type        = string
  description = "Cloud FunctionのソースコードZIPファイルのGCSオブジェクトパス。"
  default     = "inactive_accounts/function_source.v1.zip"
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}