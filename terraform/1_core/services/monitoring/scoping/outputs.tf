output "monitored_project_ids" {
  description = "モニタリング対象に追加されたプロジェクトのIDリスト。"
  value       = [for p in google_monitoring_monitored_project.monitored_projects : p.name]
}
