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
  description = "API ヘルス ダッシュボードを作成する監視対象プロジェクト ID の一覧。空ならダッシュボードを作成しない。スコーピングプロジェクトの指標スコープに含まれている必要がある。SSoT の central_monitoring=true から generate_resources.py が自動生成する。"
  default     = []
}

variable "focus_services" {
  type        = list(string)
  description = "深掘りタイルを追加する Consumed API サービス名の一覧（例: [\"generativelanguage.googleapis.com\"]）。空なら汎用（サービス非依存）ダッシュボードのみ。common.tfvars で全体共通に指定可能。"
  default     = []
}
