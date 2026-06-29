# API ヘルス ダッシュボード（スコーピングプロジェクトに作成）
#
# 監視対象プロジェクトごとに 1 枚、Consumed API 指標を軸にした汎用「API ヘルス」
# ダッシュボードを作成する。既定はサービス非依存（group-by-service）で、どの顧客でも
# そのまま利用可能。var.focus_services に特定サービス（例: generativelanguage.googleapis.com）
# を指定すると、そのサービスの深掘りタイル（レスポンス種別 / p95 / メソッド別 / quota）を追加する。
# テンプレート(api_health.json.tftpl)に project_id と focus_services を差し込んで再利用可能。
#
# 監視対象は var.monitored_project_ids（既定は空＝何も作らない。SSoT の central_monitoring=true
# から generate_resources.py が terraform.tfvars を自動生成する）。

resource "google_monitoring_dashboard" "api_health" {
  for_each = toset(var.monitored_project_ids)

  project = data.terraform_remote_state.monitoring_project.outputs.project_id

  dashboard_json = templatefile("${path.module}/api_health.json.tftpl", {
    project_id     = each.value
    focus_services = var.focus_services
  })

  lifecycle {
    # コンソールでのレイアウト微修正と毎回衝突しないよう、必要に応じて
    # ignore_changes を検討（既定では JSON を正とする）。
  }
}
