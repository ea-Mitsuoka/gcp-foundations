variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "roles" {
  type        = set(string)
  description = "Terraformが借用するサービスアカウントに付与するIAMロールのリスト。"
  default = [
  ]
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

# Warning 抑制用
variable "gcs_backend_bucket" {
  type    = string
  default = ""
}

variable "organization_domain" {
  type    = string
  default = ""
}

variable "gcp_region" {
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