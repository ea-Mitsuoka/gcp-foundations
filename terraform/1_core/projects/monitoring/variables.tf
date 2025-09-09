variable "terraform_service_account_email" {
  type        = string
  default     = ""
  description = "Terraform 実行時に借用するサービスアカウントのメールアドレス。"
}

variable "project_name" {
  type        = string
  default     = ""
  description = "プロジェクト名を作成するための名前。"
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
