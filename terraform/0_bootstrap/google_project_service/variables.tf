variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "project_id" {
  type        = string
  description = "bootstrap用のGCPプロジェクトID。"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default     = []
}
