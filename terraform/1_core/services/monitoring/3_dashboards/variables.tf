variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "monitored_project_ids" {
  type        = list(string)
  description = "API ヘルス ダッシュボードを作成する監視対象プロジェクト ID の一覧。空ならダッシュボードを作成しない。スコーピングプロジェクトの指標スコープに含まれている必要がある。"
  default     = []
}
