# Cloud BuildとCloud Functionsのサービスエージェントを強制生成
resource "google_project_service_identity" "cloudbuild_sa" {
  provider = google-beta
  project  = data.google_project.monitoring.project_id
  service  = "cloudbuild.googleapis.com"
}

resource "google_project_service_identity" "gcf_sa" {
  provider = google-beta
  project  = data.google_project.monitoring.project_id
  service  = "cloudfunctions.googleapis.com"
}


# 権限を付与するサービスエージェントのメールアドレスを動的に作成
locals {
  # Cloud FunctionsのサービスエージェントとCloud Buildのサービスエージェントのリスト
  service_agents_for_gcs_access = toset([
    google_project_service_identity.cloudbuild_sa.email,
    google_project_service_identity.gcf_sa.email,
  ])
}

# Cloud Functionのソースコードが保管されているGCSバケットに対して、
# 上記で定義したサービスエージェントに読み取り権限を付与
resource "google_storage_bucket_iam_member" "service_agents_source_bucket_reader" {
  for_each = local.service_agents_for_gcs_access

  bucket = data.terraform_remote_state.bootstrap.outputs.function_source_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${each.key}"
}
