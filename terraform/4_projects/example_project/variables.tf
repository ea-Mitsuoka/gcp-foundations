variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名"
  default     = ""
}

variable "gcp_region" {
  type        = string
  description = "GCPリージョン"
  default     = "asia-northeast1"
}

variable "project_id_prefix" {
  type        = string
  description = "プロジェクトIDの接頭辞（ドメイン名ベース）"
}

variable "app_name" {
  type        = string
  description = "アプリケーション名"
}

variable "environment" {
  type        = string
  description = "環境名 (dev, stag, prodなど)"
}

variable "folder_id" {
  type        = string
  default     = ""
  description = "プロジェクトを作成するフォルダのID。空文字なら組織直下"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}
