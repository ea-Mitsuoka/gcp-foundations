variable "organization_id" {
  type        = string
  description = "プロジェクトを作成する組織のID。"
}

variable "organization_name" {
  type        = string
  description = "プロジェクトIDのプレフィックスとして使用する組織名。"
}

variable "project_name" {
  type        = string
  description = "プロジェクト名を作成するための名前。"
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}
