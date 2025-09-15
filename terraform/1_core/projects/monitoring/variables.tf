variable "project_name" {
  type        = string
  default     = ""
  description = "プロジェクト名を作成するための名前。"
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}
