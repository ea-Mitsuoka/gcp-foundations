output "prod_host_project_id" {
  description = "The ID of the Production Shared VPC host project."
  value       = var.enable_vpc_host_projects ? module.vpc_host_prod[0].project_id : null
}

output "dev_host_project_id" {
  description = "The ID of the Development Shared VPC host project."
  value       = var.enable_vpc_host_projects ? module.vpc_host_dev[0].project_id : null
}
