provider "google" {
  # 継承に頼らず、このディレクトリで直接サービスアカウント借用を指定する
  impersonate_service_account = var.terraform_service_account_email
  # 操作対象のプロジェクトも明示
  project = var.project_id
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = var.project_id
}
