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

variable "vpc_sc" {
  type        = string
  description = "このプロジェクトを所属させる VPC Service Controls の境界名。空文字の場合は対象外。"
  default     = ""
}

variable "shared_vpc_subnet" {
  type        = string
  description = "接続する Shared VPC のサブネット名。空文字の場合は対象外。"
  default     = ""
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

variable "enable_vpc_sc" {
  type        = bool
  description = "VPC Service Controls が全体で有効か（共通変数から渡される）"
  default     = false
}

variable "enable_org_policies" {
  type        = bool
  description = "組織ポリシーを適用するかどうか。"
  default     = false
}

variable "enable_tags" {
  type        = bool
  description = "組織レベルのタグ機能を有効化するかどうか。"
  default     = false
}

variable "org_tags" {
  type        = list(string)
  description = "プロジェクトに紐付けるタグのリスト（key/value形式）。"
  default     = []
}

variable "monitoring" {
  type        = bool
  description = "監視を有効にするかどうか。"
  default     = true
}

variable "logging" {
  type        = bool
  description = "ログ収集を有効にするかどうか。"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "プロジェクトの削除保護を有効にするかどうか。"
  default     = true
}

variable "budget_amount" {
  type        = number
  description = "月額予算。0の場合はアラートを作成しません。"
  default     = 0
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "追加の予算アラート通知先メールアドレス。"
  default     = []
}

variable "billing_account_id" {
  type        = string
  description = "予算アラートを紐付ける請求先アカウントID。プロジェクト作成後の手動紐付け後に有効になります。"
  default     = null
}

variable "mgmt_project_id" {
  type        = string
  description = "管理プロジェクトのID。通知チャネルの作成先として使用します。"
  default     = null
}

