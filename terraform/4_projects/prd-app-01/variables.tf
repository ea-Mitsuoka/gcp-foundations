variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名"
  default     = ""
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

variable "vpc_sc" {
  type        = bool
  description = "このプロジェクトをVPC Service Controlsの境界に含めるかどうか。"
  default     = false
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

variable "shared_vpc_env" {
  type        = string
  description = "接続する Shared VPC の環境 (prod, dev, none)"
  default     = "none"
}

variable "enable_shared_vpc" {
  type        = bool
  description = "Shared VPC が全体で有効か（共通変数から渡される）"
  default     = false
}

variable "billing_linked" {
  type        = bool
  description = "課金アカウントが紐づいているか"
  default     = false
}

