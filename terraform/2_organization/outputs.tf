output "service_perimeter_name" {
  value       = var.enable_vpc_sc ? google_access_context_manager_service_perimeter.default_perimeter[0].name : null
  description = "デフォルトのVPC-SCサービスペリメータ名"
}
