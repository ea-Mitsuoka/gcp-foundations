variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "roles" {
  type        = set(string)
  description = "Terraformが借用するサービスアカウントに付与するIAMロールのリスト。"
  default = [
  ]
}
