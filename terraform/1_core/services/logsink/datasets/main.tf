# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# logsinkプロジェクトの情報をリモートステートから取得
data "terraform_remote_state" "logsink_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}

# 共有のセキュリティ分析用データセットを作成
resource "google_bigquery_dataset" "analytics_dataset" {
  project     = data.terraform_remote_state.logsink_project.outputs.project_id
  dataset_id  = "security_analytics"
  location    = var.gcp_region
  description = "Dataset for various security analytics views."
}

# 90日間未ログインユーザーを検知するビュー
resource "google_bigquery_table" "inactive_users_view" {
  project    = data.terraform_remote_state.logsink_project.outputs.project_id
  dataset_id = google_bigquery_dataset.analytics_dataset.dataset_id
  table_id   = "inactive_users_view"

  view {
    query = <<EOF
WITH 
  -- 過去90日間に活動があったユーザーを抽出
  active_users AS (
    SELECT DISTINCT 
      protopayload_auditlog.authenticationInfo.principalEmail as email
    FROM 
      `${data.terraform_remote_state.logsink_project.outputs.project_id}.audit_logs.cloudaudit_googleapis_com_activity_*`
    WHERE 
      _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  ),
  -- 現在何らかの権限を持っているユーザーをアセットインベントリから抽出
  all_users_with_roles AS (
    SELECT DISTINCT 
      SUBSTR(member, 6) as email -- "user:email@example.com" から "email@example.com" を抽出
    FROM 
      `${data.terraform_remote_state.logsink_project.outputs.project_id}.asset_inventory.iam_policy`,
      UNNEST(policy.bindings) AS binding,
      UNNEST(binding.members) AS member
    WHERE 
      STARTS_WITH(member, 'user:')
  )
SELECT 
  all.email
FROM 
  all_users_with_roles all
LEFT JOIN 
  active_users active ON all.email = active.email
WHERE 
  active.email IS NULL
  AND all.email IS NOT NULL
  AND NOT ENDS_WITH(all.email, 'gserviceaccount.com') -- サービスアカウントを念のため除外
EOF
    use_legacy_sql = false
  }
}
