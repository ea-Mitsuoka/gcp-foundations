variable "project_id" {
  type        = string
  description = "Terraformで操作するGCPプロジェクトのIDです。"
}

variable "gcp_region" {
  type        = string
  default     = "asia-northeast1"
  description = "リソースを作成するデフォルトリージョン。"
}

