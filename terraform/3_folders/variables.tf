variable "organization_domain" {
  type        = string
  description = "フォルダを作成する親となるGCP組織のドメイン名"
}
variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcp_region" {
  type        = string
  description = "リソースを作成するデフォルトリージョン。"
  default     = "asia-northeast1"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "enable_org_policies" {
  type        = bool
  description = "組織ポリシーを適用するかどうか。"
  default     = false
}

variable "enable_tags" {
  type        = bool
  description = "組織レベルのタグ機能を有効化するかどうか。"
  default     = false
}

