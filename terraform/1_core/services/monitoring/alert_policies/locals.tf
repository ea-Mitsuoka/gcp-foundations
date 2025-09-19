locals {
  # (alert_definitions_map, notifications, active_notifications, unique_emails_to_notify の定義は変更なし)
  alert_definitions_map   = { for d in csvdecode(file(var.alert_definitions_csv_path)) : d.alert_name => d }
  notifications           = csvdecode(file(var.notifications_csv_path))
  active_notifications    = [for r in local.notifications : r if lower(r.receive_alerts) == "true"]
  unique_emails_to_notify = toset([for r in local.active_notifications : r.user_email])

  # ★★★ ここからが修正箇所 ★★★

  # 1. project_idとalert_nameの組み合わせで通知設定をグループ化する
  #    キーが同じ行は、自動的にリストにまとめられる
  grouped_notifications = {
    for row in local.active_notifications : "${row.project_id}:${row.alert_name}" => row...
  }

  # 2. グループ化されたデータを基に、最終的なalert_subscriptionsマップを生成する
  alert_subscriptions = {
    # grouped_notifications をループ処理することで、キーの重複がなくなる
    for key, rows in local.grouped_notifications : key => {
      # グループ内の最初の行(rows[0])を代表として使い、共通の値を取得
      monitored_project_id = rows[0].project_id,
      alert_display_name   = local.alert_definitions_map[rows[0].alert_name].alert_display_name,
      alert_documentation  = local.alert_definitions_map[rows[0].alert_name].alert_documentation,
      metric_type          = data.terraform_remote_state.log_metrics_state.outputs.log_metrics[rows[0].alert_name].type,

      # グループ内の全ての行(rows)からメールアドレスを抽出してリストを作成
      notification_emails = [
        for r in rows : r.user_email
      ]
    }
  }
}
