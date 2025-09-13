variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}

variable "organization_domain" {
  type        = string
  description = "GCP組織のドメイン名。"
}
