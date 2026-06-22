# API ヘルス ダッシュボード（スコーピングプロジェクトに作成）
#
# 監視対象プロジェクトごとに 1 枚、Consumed API 指標を軸に
# Gemini API / Vertex AI を中心とした「API ヘルス」ダッシュボードを作成する。
# テンプレート(customer_api_health.json.tftpl)に project_id を差し込んで再利用可能。
#
# 監視対象は var.monitored_project_ids（既定は空＝何も作らない）。
# 例: terraform.tfvars に monitored_project_ids = ["<監視対象プロジェクトID>"]

resource "google_monitoring_dashboard" "api_health" {
  for_each = toset(var.monitored_project_ids)

  project = data.terraform_remote_state.monitoring_project.outputs.project_id

  dashboard_json = templatefile("${path.module}/customer_api_health.json.tftpl", {
    project_id = each.value
  })

  lifecycle {
    # コンソールでのレイアウト微修正と毎回衝突しないよう、必要に応じて
    # ignore_changes を検討（既定では JSON を正とする）。
  }
}
