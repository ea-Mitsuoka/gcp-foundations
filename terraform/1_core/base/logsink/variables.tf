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

variable "roles" {
  type        = set(string)
  description = "Terraformが借用するサービスアカウントに付与するIAMロールのリスト。"
  default = [
  ]
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
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
