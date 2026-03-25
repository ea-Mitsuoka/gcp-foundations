<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | ~> 1.14 |
| <a name="requirement_google"></a> [google](#requirement_google) | ~> 6.48.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider_google) | ~> 6.48.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_monitoring_alert_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_display_name"></a> [alert_display_name](#input_alert_display_name) | Cloud Monitoringでのアラートポリシーの表示名。 | `string` | n/a | yes |
| <a name="input_alert_documentation"></a> [alert_documentation](#input_alert_documentation) | アラート発生時に通知されるメッセージに含めるドキュメント。Markdown形式で記述可能。 | `string` | n/a | yes |
| <a name="input_metric_type"></a> [metric_type](#input_metric_type) | アラートをトリガーするCloud Monitoringメトリックのタイプ。（例: 'logging.googleapis.com/log_entry_count'） | `string` | n/a | yes |
| <a name="input_monitored_project_id"></a> [monitored_project_id](#input_monitored_project_id) | 監視対象となるリソースが存在するGCPプロジェクトのID。 | `string` | n/a | yes |
| <a name="input_notification_channel_ids"></a> [notification_channel_ids](#input_notification_channel_ids) | アラート通知を送信するCloud Monitoring通知チャネルのIDリスト。 | `list(string)` | `[]` | no |
| <a name="input_scoping_project_id"></a> [scoping_project_id](#input_scoping_project_id) | アラートポリシーを作成するモニタリングプロジェクトのID。（メトリクススコーププロジェクト） | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
