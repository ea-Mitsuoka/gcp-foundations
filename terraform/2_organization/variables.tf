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

variable "enable_vpc_sc" {
  type        = bool
  description = "VPC Service Controls を有効にするかどうか。"
  default     = false
}

variable "enable_org_policies" {
  type        = bool
  description = "組織ポリシーを適用するかどうか。"
  default     = false
}

