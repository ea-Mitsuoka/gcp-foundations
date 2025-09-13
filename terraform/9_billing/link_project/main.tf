# Step 1: 課金管理者としてgcloudにログインしておく
# gcloud auth application-default login

terraform {
  backend "gcs" {
    bucket = "your-tf-state-bucket"
    prefix = "billing/link_project"
  }
}

# どのプロジェクトを対象にするか、tfstateから読み込む
data "terraform_remote_state" "project_to_link" {
  backend = "gcs"
  config = {
    bucket = local.gcs_backend_bucket # locals.tfで管理
    # 4_projects/example_project のtfstateを指定
    prefix = "projects/example_project"
  }
}

# 課金アカウントIDを変数として渡す
variable "billing_account_id" {
  type        = string
  description = "リンクする課金アカウントのID。"
}

# 課金アカウントとプロジェクトをリンクさせるリソース
resource "google_project_billing_info" "project_billing" {
  project         = data.terraform_remote_state.project_to_link.outputs.project_id
  billing_account = var.billing_account_id
}
