variable "project_id" {
  type        = string
  description = "Terraformで操作するGCPプロジェクトのIDです。"
}

variable "gcp_region" {
  type        = string
  default     = "asia-northeast1"
  description = "リソースを作成するデフォルトリージョン。"
}

# Warning 抑制用（common.tfvarsから渡されるが0_bootstrapでは使用しない変数）
variable "terraform_service_account_email" {
  type    = string
  default = ""
}

variable "gcs_backend_bucket" {
  type    = string
  default = ""
}

variable "organization_domain" {
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