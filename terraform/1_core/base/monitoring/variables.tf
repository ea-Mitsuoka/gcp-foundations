variable "project_name" {
  type        = string
  default     = "monitoring"
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

variable "gcp_region" {
  type        = string
  description = "プロジェクトのデフォルトリージョン。"
  default     = "asia-northeast1"
}

variable "project_id_prefix" {
  type        = string
  description = "プロジェクトIDの接頭辞（ドメイン名ベース・文字数制限対応済）"
}