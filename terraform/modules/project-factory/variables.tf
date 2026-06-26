variable "project_id" {
  type        = string
  description = "The ID of the project."
}

variable "name" {
  type        = string
  description = "The display name of the project."
}

variable "organization_id" {
  type        = string
  description = "The organization ID to create the project in."
}

variable "folder_id" {
  type        = string
  description = "The folder ID to create the project in. If null, project will be created at the organization level."
  default     = null
}

variable "labels" {
  type        = map(string)
  description = "A map of labels to assign to the project."
  default     = {}
}

variable "auto_create_network" {
  type        = bool
  description = "If true, the default network will be created. Defaults to true."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Whether or not to protect the project from deletion. Internally mapped to google_project's deletion_policy (PREVENT/DELETE). Default is true."
  default     = true
}

variable "budget_amount" {
  type        = number
  description = "The monthly budget amount for the project. If 0, no budget alert is created."
  default     = 0
}

variable "billing_account" {
  type        = string
  description = "The billing account ID to associate the budget with. Required if budget_amount > 0."
  default     = null
}

variable "monitoring_project_id" {
  type        = string
  description = "The ID of the project where notification channels will be created (usually the management or central monitoring project)."
  default     = null
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "List of additional email addresses to receive budget alerts."
  default     = []
}

variable "budget_threshold_percents" {
  type        = list(number)
  description = "Budget alert threshold percentages (e.g. [0.5, 0.9, 1.0] = 50%/90%/100%)."
  default     = [0.5, 0.9, 1.0]
}

# --- 既存プロジェクト採用(adopt)モード ---
variable "create_project" {
  type        = bool
  description = "true(既定)は新規作成フロー。false の場合は既存プロジェクトの採用(adopt)モードとなり、project_id_override の既存IDを採用する（実体は terraform import で state に取り込む）。"
  default     = true
}

variable "project_id_override" {
  type        = string
  description = "採用(adopt)モードで使用する既存プロジェクトID。create_project=false かつ空文字でない場合に var.project_id の代わりに使用する。"
  default     = ""
}