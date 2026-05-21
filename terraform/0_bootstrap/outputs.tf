output "admin_folder_id" {
  description = "管理系プロジェクトを配置するフォルダのリソース名（folders/{folder_id} 形式）。"
  value       = google_folder.admin.name
}

output "network_folder_id" {
  description = "ネットワーク基盤プロジェクトを配置するフォルダのリソース名（folders/{folder_id} 形式）。"
  value       = google_folder.network.name
}
