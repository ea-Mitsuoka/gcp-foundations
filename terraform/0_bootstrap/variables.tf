variable "project_id" {
  type        = string
  description = "Terraformで操作するGCPプロジェクトのIDです。"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "function_source_bucket_name" {
  type        = string
  description = "Cloud Functionのソースコード(ZIP)を保管するためのGCSバケット名です。"
  default     = "" # 空文字の場合、main.tf内で自動生成されます
}

variable "location" {
  type        = string
  description = "Cloud Function等のリージョンです。"
  default     = "asia-northeast1"
}
