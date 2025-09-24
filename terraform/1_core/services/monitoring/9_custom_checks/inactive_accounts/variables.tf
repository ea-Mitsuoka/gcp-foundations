variable "gcs_backend_bucket" {
  type        = string
  description = "Terraformの状態ファイルを保存するGCSバケット名。"
}

variable "gcp_region" {
  type        = string
  description = "リソースを作成するデフォルトリージョン。"
  default     = "asia-northeast1"
}

variable "function_source_bucket" {
  type        = string
  description = "Cloud Functionのソースコード(ZIP)をアップロードしたGCSバケット名。"
}

variable "function_source_object" {
  type        = string
  description = "Cloud FunctionのソースコードZIPファイルのGCSオブジェクトパス。"
  default     = "inactive_accounts/function_source.v1.zip"
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}