variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "project_id" {
  type        = string
  description = "bootstrap用のGCPプロジェクトID。"
}

variable "roles" {
  type        = set(string)
  description = "Terraformが借用するサービスアカウントに付与するIAMロールのリスト。"
  default = [
    "roles/storage.admin" # SAが別プロジェクトから自身の管理用GCSバケットのIAMを操作するために必須
  ]
}
