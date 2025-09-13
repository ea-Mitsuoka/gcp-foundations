variable "project_id" {
  type        = string
  description = "The ID of the project to which IAM permissions will be granted."
}

variable "member" {
  type        = string
  description = "The member (user, service account, etc.) to whom the roles will be granted."
}

variable "roles" {
  type        = set(string)
  description = "A list of IAM roles to grant to the member."
  default     = []
}
