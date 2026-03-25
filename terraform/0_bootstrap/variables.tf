variable "project_id" {
  type        = string
  description = "Terraformで操作するGCPプロジェクトのIDです。"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}
