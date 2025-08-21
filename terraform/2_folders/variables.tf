variable "organization_id" {
  type        = string
  description = "フォルダを作成する親となるGCP組織ID。"
}
variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}
