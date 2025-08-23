variable "organization_name" {
  type        = string
  description = "組織の名前（project_id 生成用に正規化する）。"
}

variable "organization_id" {
  type        = string
  description = "作成するGCPプロジェクトが属する組織のID。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "folder_path" {
  type        = string
  default     = ""
  description = "プロジェクトを作成するフォルダのパス。空文字なら組織直下"
}

variable "billing_account_id" {
  type        = string
  description = "紐付ける請求先アカウントのID。"
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
