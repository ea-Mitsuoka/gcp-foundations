data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = local.gcs_backend_bucket
    prefix = "core/projects/monitoring"
  }
}

data "google_organization" "org" {
  domain = var.organization_domain
}

data "google_projects" "all_projects" {
  # 組織IDとアクティブなプロジェクトという条件でフィルタリング
  filter = "parent.id=${data.google_organization.org.org_id} lifecycleState=ACTIVE"
}
