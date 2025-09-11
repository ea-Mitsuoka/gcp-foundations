provider "google" {
  # # このTerraformが操作する対象のプロジェクトID
  # project = data.terraform_remote_state.project.outputs.project_id
  # この設定により、Terraform実行時に自動でSAを借用します
  impersonate_service_account = var.terraform_service_account_email
}

# provider "google-beta" {
#   project = data.terraform_remote_state.project.outputs.project_id
#   # googleプロバイダーと同じ認証情報 (SAの借用) を使用します
#   impersonate_service_account = var.terraform_service_account_email
# }