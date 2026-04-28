variable "project_id" {
  type        = string
  description = "bootstrap用のGCPプロジェクトID。"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default = [
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "iamcredentials.googleapis.com",
    "orgpolicy.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "cloudasset.googleapis.com"
  ]
}
