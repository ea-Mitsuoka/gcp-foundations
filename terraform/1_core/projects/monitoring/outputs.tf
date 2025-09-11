# プロジェクトID
output "project_id" {
  description = "The ID of the created project."
  value       = module.logsink_project.project_id
}

# プロジェクト名
output "project_name" {
  description = "The display name of the created project."
  value       = module.logsink_project.project_name
}
