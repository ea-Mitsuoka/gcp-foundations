data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}

data "google_organization" "org" {
  # 注入された変数を参照
  domain = var.organization_domain
}

data "google_project" "logsink" {
  project_id = data.terraform_remote_state.project.outputs.project_id
}