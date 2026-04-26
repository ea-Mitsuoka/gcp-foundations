variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "tfstateを保存するGCSバケット。"
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

variable "enable_vpc_host_projects" {
  type        = bool
  description = "Shared VPC用のホストプロジェクトを作成するかどうか。"
  default     = false
}
