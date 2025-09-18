output "log_metrics" {
  description = "A map of created log metrics, keyed by alert_name."
  value = {
    for k, v in module.log_metrics : k => {
      name = v.name
      type = v.type
    }
  }
}
