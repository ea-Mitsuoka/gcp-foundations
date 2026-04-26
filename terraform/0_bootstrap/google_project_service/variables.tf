variable "project_id" {
  type        = string
  description = "bootstrap用のGCPプロジェクトID。"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default = [
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "iamcredentials.googleapis.com",
    "orgpolicy.googleapis.com",
    "logging.googleapis.com"
  ]
}

# --- common.tfvars variables ---

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}

variable "gcp_region" {
  type        = string
  description = "デフォルトのGCPリージョン。"
}

variable "project_id_prefix" {
  type        = string
  description = "プロジェクトIDの接頭辞。"
}

variable "core_billing_linked" {
  type        = bool
  description = "コアプロジェクトの課金アカウントが紐づいているか。"
}

variable "enable_vpc_host_projects" {
  type        = bool
  description = "共有VPCホストプロジェクトを有効にするか。"
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
