variable "project_id" {
  type        = string
  description = "ログベース指標を作成する対象のプロジェクトID。"
}

variable "metric_name" {
  type        = string
  description = "作成するログベース指標の名前。"
}

variable "metric_filter" {
  type        = string
  description = "作成するログベース指標のフィルタ。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "Service account email used by Terraform to perform operations (if applicable)."
  default     = ""
}
