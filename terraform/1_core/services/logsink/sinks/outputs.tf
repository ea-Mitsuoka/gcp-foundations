output "admin_activity_dataset_id" {
  description = "The dataset ID for the Admin Activity audit logs sink."
  # local.sink_configsの中から、キーが "admin_activity_audit_logs" のものを探し、
  # その宛先名 (destination_parent) を直接出力します。
  value = local.sink_configs["admin_activity_audit_logs"].destination_parent
}
