# monitoringプロジェクトのプロジェクト番号などを取得
data "google_project" "monitoring" {
  project_id = data.terraform_remote_state.project.outputs.project_id
}

# サービスエージェントのメールアドレスと、それぞれに付与するロールを定義
locals {
  compute_default_service_agent = "${data.google_project.monitoring.number}-compute@developer.gserviceaccount.com"

  # Compute Engineデフォルトサービスエージェントに必要な全ロールのリスト
  compute_default_sa_roles = toset([
    "roles/logging.logWriter",       # ビルドログの書き込みに必要
    "roles/storage.objectViewer",    # ステージングGCSバケットからの読み取りに必要
    "roles/artifactregistry.reader", # Artifact Registryキャッシュの読み取りに必要
    "roles/artifactregistry.writer", # Artifact Registryへのイメージ書き込みに必要
    "roles/run.admin",               # Cloud Runサービスとしてデプロイするために必要
    "roles/iam.serviceAccountUser",  # 関数の実行SAとして振る舞うために必要
  ])
}

# Compute Engineデフォルトサービスエージェントに必要な全ロールを付与
resource "google_project_iam_member" "compute_default_agent_roles" {
  for_each = local.compute_default_sa_roles

  project = data.terraform_remote_state.project.outputs.project_id
  role    = each.key
  member  = "serviceAccount:${local.compute_default_service_agent}"
}

# Cloud Buildサービスエージェントはこのビルドでは使用されないため、関連するリソースは不要です。
# 以前のコードが残っている場合はこの機会に削除します。