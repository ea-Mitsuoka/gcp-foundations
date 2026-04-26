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

# --- common.tfvars variables ---

variable "core_billing_linked" {
  type        = bool
  description = "コアプロジェクトの課金アカウントが紐づいているか。"
}

variable "enable_shared_vpc" {
  type        = bool
  description = "共有VPC機能を有効にするか。"
}

variable "enable_vpc_sc" {
  type        = bool
  description = "VPC Service Controlsを有効にするか。"
}

variable "enable_org_policies" {
  type        = bool
  description = "組織ポリシーを有効にするか。"
}

variable "enable_simplified_admin_groups" {
  type        = bool
  description = "簡素化された管理グループ（9つではなく2つ）を有効にするか。"
}
