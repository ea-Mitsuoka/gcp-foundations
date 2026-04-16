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
  description = "プロジェクトのデフォルトリージョン。"
  default     = "asia-northeast1"
}
