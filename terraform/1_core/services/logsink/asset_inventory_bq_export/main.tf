# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# --------------------------------------------------------------------------------
# 1. Pub/Sub スキーマとトピックの定義
# --------------------------------------------------------------------------------
resource "google_pubsub_topic" "asset_inventory_feed" {
  provider = google-beta
  project  = data.terraform_remote_state.project.outputs.project_id
  name     = "asset-inventory-iam-policy-feed"
}

# --------------------------------------------------------------------------------
# 2. BigQuery データセットとテーブルの定義
# --------------------------------------------------------------------------------
resource "google_bigquery_dataset" "asset_inventory_dataset" {
  project     = data.terraform_remote_state.project.outputs.project_id
  dataset_id  = "asset_inventory"
  location    = var.gcp_region
  description = "Dataset for Cloud Asset Inventory exports."
}

resource "google_bigquery_table" "asset_inventory_iam_policy_table" {
  project    = data.terraform_remote_state.project.outputs.project_id
  dataset_id = google_bigquery_dataset.asset_inventory_dataset.dataset_id
  table_id   = "iam_policy"
  schema     = file("${path.module}/iam_policy_schema.json")

  deletion_protection = false
}

# --------------------------------------------------------------------------------
# 綺麗にカラム展開された状態を提供する BigQuery View（仮想テーブル）
# --------------------------------------------------------------------------------
resource "google_bigquery_table" "asset_inventory_iam_policy_view" {
  project    = data.terraform_remote_state.project.outputs.project_id
  dataset_id = google_bigquery_dataset.asset_inventory_dataset.dataset_id
  
  # テーブル名の頭に view を意味する v_ をつけるのが一般的です
  table_id   = "v_iam_policy"

  view {
    use_legacy_sql = false
    # ユーザーが叩かなくても、裏側で常にこのSQLが適用された状態になります
    query = <<EOF
SELECT
  CAST(JSON_VALUE(data, '$.window.startTime') AS TIMESTAMP) AS event_time,
  JSON_VALUE(data, '$.asset.assetType') AS asset_type,
  JSON_VALUE(data, '$.asset.name') AS resource_name,

  -- JSONの配列を、BigQueryネイティブの ARRAY<STRUCT> に美しく再構築します
  ARRAY(
    SELECT AS STRUCT
      JSON_VALUE(binding, '$.role') AS role,
      JSON_VALUE_ARRAY(binding, '$.members') AS members
    FROM UNNEST(JSON_QUERY_ARRAY(data, '$.asset.iamPolicy.bindings')) AS binding
  ) AS policy_bindings,

  -- deleted キーが存在しない場合(NULL)は FALSE として扱う安全な書き方
  IFNULL(CAST(JSON_VALUE(data, '$.deleted') AS BOOL), FALSE) AS is_deleted
FROM
  `${google_bigquery_table.asset_inventory_iam_policy_table.project}.${google_bigquery_table.asset_inventory_iam_policy_table.dataset_id}.${google_bigquery_table.asset_inventory_iam_policy_table.table_id}`
EOF
  }

  deletion_protection = false

  # ★重要: 必ず物理テーブルが作られてからViewを作成するように強制する
  depends_on = [
    google_bigquery_table.asset_inventory_iam_policy_table
  ]
}

# --------------------------------------------------------------------------------
# 3. Cloud Asset Inventory (CAI) フィードと権限設定
# --------------------------------------------------------------------------------
# プロジェクトレベルのCAIサービスエージェントを明示的に生成（GCPに必ず存在するSAです）
resource "google_project_service_identity" "asset_inventory_sa" {
  provider = google-beta
  project  = data.terraform_remote_state.project.outputs.project_id
  service  = "cloudasset.googleapis.com"
}

# 生成されたプロジェクトレベルのSAに、トピックへの書き込み権限を付与
resource "google_pubsub_topic_iam_member" "asset_inventory_sa_publisher" {
  project = data.terraform_remote_state.project.outputs.project_id
  topic   = google_pubsub_topic.asset_inventory_feed.name
  role    = "roles/pubsub.publisher"
  member  = google_project_service_identity.asset_inventory_sa.member
}

# 組織フィードの作成
resource "google_cloud_asset_organization_feed" "iam_policy_feed" {
  provider        = google-beta
  billing_project = data.terraform_remote_state.project.outputs.project_id
  org_id          = data.google_organization.org.org_id
  feed_id         = "iam-policy-to-bigquery"
  content_type    = "IAM_POLICY"

  asset_types = [
    "cloudresourcemanager.googleapis.com/Project",
    "cloudresourcemanager.googleapis.com/Folder",
    "cloudresourcemanager.googleapis.com/Organization"
  ]

  feed_output_config {
    pubsub_destination {
      topic = google_pubsub_topic.asset_inventory_feed.id
    }
  }

  # 権限付与が完了してからフィードを作成する正しい依存関係
  depends_on = [
    google_pubsub_topic_iam_member.asset_inventory_sa_publisher
  ]
}

# --------------------------------------------------------------------------------
# 4. Pub/Sub -> BigQuery サブスクリプションと権限設定
# --------------------------------------------------------------------------------
resource "google_project_service_identity" "pubsub_sa" {
  provider = google-beta
  project  = data.terraform_remote_state.project.outputs.project_id
  service  = "pubsub.googleapis.com"
}

resource "google_project_iam_member" "pubsub_sa_bq_writer" {
  project = data.google_project.logsink.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_project_service_identity.pubsub_sa.email}"
}

resource "google_pubsub_subscription" "asset_inventory_to_bq" {
  provider = google-beta
  project  = data.terraform_remote_state.project.outputs.project_id
  name     = "sub-asset-inventory-to-bq"
  topic    = google_pubsub_topic.asset_inventory_feed.name

  bigquery_config {
    table               = "${google_bigquery_table.asset_inventory_iam_policy_table.project}:${google_bigquery_table.asset_inventory_iam_policy_table.dataset_id}.${google_bigquery_table.asset_inventory_iam_policy_table.table_id}"
    write_metadata      = false
    use_topic_schema    = false
    drop_unknown_fields = true
  }

  depends_on = [
    google_project_iam_member.pubsub_sa_bq_writer
  ]
}
