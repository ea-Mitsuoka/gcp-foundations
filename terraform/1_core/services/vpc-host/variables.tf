
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

variable "enable_vpc_host_projects" {
  type        = bool
  description = "Shared VPC用のホストプロジェクトを作成するかどうか。"
  default     = false
}

variable "enable_shared_vpc" {
  type        = bool
  description = "ホストプロジェクトに対してShared VPC機能を有効化するかどうか。"
  default     = false
}
