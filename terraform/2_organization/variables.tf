variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcp_region" {
  type        = string
  description = "プロジェクトのデフォルトリージョン。"
  default     = "asia-northeast1"
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

# Warning 抑制用
variable "gcs_backend_bucket" {
  type    = string
  default = ""
}

variable "project_id_prefix" {
  type    = string
  default = ""
}

variable "core_billing_linked" {
  type    = bool
  default = false
}