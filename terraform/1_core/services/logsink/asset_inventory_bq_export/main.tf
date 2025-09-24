# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# 1. Pub/Subスキーマを定義
resource "google_pubsub_schema" "iam_policy_schema" {
  project = data.terraform_remote_state.project.outputs.project_id
  name    = "asset-inventory-iam-policy-schema"
  type    = "AVRO" # JSONを扱う場合でもAVROかPROTOCOL_BUFFERの指定が必要
  definition = jsonencode({
    type = "record",
    name = "IamPolicy",
    fields = [
      { name = "asset_type", type = "string" },
      { name = "resource", type = "string" },
      {
        name = "policy",
        type = {
          type = "record",
          name = "Policy",
          fields = [
            { name = "version", type = "int" },
            {
              name = "bindings",
              type = {
                type = "array",
                items = {
                  type = "record",
                  name = "Binding",
                  fields = [
                    { name = "role", type = "string" },
                    { name = "members", type = { type = "array", items = "string" } }
                  ]
                }
              }
            },
            { name = "etag", type = "string" }
          ]
        }
      }
    ]
  })
}

# 2. アセット更新情報を受け取るためのPub/Subトピック
resource "google_pubsub_topic" "asset_inventory_feed" {
  project = data.terraform_remote_state.project.outputs.project_id
  name = "asset-inventory-iam-policy-feed"

  # 2. トピックにスキーマを関連付ける
  schema_settings {
    schema   = google_pubsub_schema.iam_policy_schema.id
    encoding = "JSON"
  }
}

# asset_inventory データセットを"新規作成"する
resource "google_bigquery_dataset" "asset_inventory_dataset" {
  project = data.terraform_remote_state.project.outputs.project_id
  dataset_id  = "asset_inventory"
  location    = "asia-northeast1" # リージョンを指定
  description = "Dataset for Cloud Asset Inventory exports."
}

# 4. エクスポート先のBigQueryテーブル
resource "google_bigquery_table" "asset_inventory_iam_policy_table" {
  project = data.terraform_remote_state.project.outputs.project_id
  dataset_id = google_bigquery_dataset.asset_inventory_dataset.dataset_id
  table_id   = "iam_policy"

  # Cloud Asset InventoryのIAMポリシーのスキーマ定義
  schema = file("${path.module}/iam_policy_schema.json")

  deletion_protection=false
}
# iam_policy_schema.json の内容はGoogle公式ドキュメントを参照してください
# https://cloud.google.com/asset-inventory/docs/exporting-to-bigquery?hl=ja#iam_policy_analysis_real-time_schema

# 5. Pub/SubからBigQueryへメッセージを書き込むためのSubscription
resource "google_pubsub_subscription" "asset_inventory_to_bq" {
  project = data.terraform_remote_state.project.outputs.project_id
  name  = "sub-asset-inventory-to-bq"
  topic = google_pubsub_topic.asset_inventory_feed.name

  bigquery_config {
    table            = "${google_bigquery_table.asset_inventory_iam_policy_table.project}:${google_bigquery_table.asset_inventory_iam_policy_table.dataset_id}.${google_bigquery_table.asset_inventory_iam_policy_table.table_id}"
    write_metadata   = false
    # 3. トピックのスキーマを使用するよう設定
    use_topic_schema = true
  }
  # このIAMバインディングが完了するまで待つように設定
  depends_on = [
    google_project_iam_member.pubsub_sa_bq_writer
  ]
}

# 6. Cloud Asset Inventoryのフィード設定
resource "google_cloud_asset_organization_feed" "iam_policy_feed" {
  billing_project = data.terraform_remote_state.project.outputs.project_id
  org_id          = data.google_organization.org.org_id
  feed_id         = "iam-policy-to-bigquery"
  content_type    = "IAM_POLICY"

  # IAMポリシーを持つ可能性のある主要なアセットタイプを指定
  asset_types = [
    "cloudresourcemanager.googleapis.com/Project",
    "cloudresourcemanager.googleapis.com/Folder",
    "cloudresourcemanager.googleapis.com/Organization"
  ]

  feed_output_config {
    # Publish feed to Pub/Sub; subscribe or export from Pub/Sub to BigQuery separately.
    pubsub_destination {
      topic = google_pubsub_topic.asset_inventory_feed.id
    }
  }
}

# 必要なIAM設定：
# Cloud Asset InventoryのサービスエージェントにPub/Subトピックへの発行権限を付与
resource "google_pubsub_topic_iam_member" "asset_inventory_sa_publisher" {
  project = data.terraform_remote_state.project.outputs.project_id
  topic  = google_pubsub_topic.asset_inventory_feed.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.logsink.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"
}

# Pub/SubサービスエージェントにBigQueryデータ編集者ロールを明示的に付与
resource "google_project_iam_member" "pubsub_sa_bq_writer" {
  project = data.google_project.logsink.project_id
  role    = "roles/bigquery.dataEditor"
  # "service-[プロジェクト番号]@gcp-sa-pubsub.iam.gserviceaccount.com" という形式のメンバーを動的に生成
  member  = "serviceAccount:service-${data.google_project.logsink.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
