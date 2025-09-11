data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/projects/logsink"
  }
}

data "external" "org_id" {
  program = ["bash", "${local.scripts_dir}/get-organization-id.sh"]
}
