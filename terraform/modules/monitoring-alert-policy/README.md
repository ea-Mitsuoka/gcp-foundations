<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.14 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.48.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.48.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_monitoring_alert_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_display_name"></a> [alert\_display\_name](#input\_alert\_display\_name) | Cloud Monitoringでのアラートポリシーの表示名。 | `string` | n/a | yes |
| <a name="input_alert_documentation"></a> [alert\_documentation](#input\_alert\_documentation) | アラート発生時に通知されるメッセージに含めるドキュメント。Markdown形式で記述可能。 | `string` | n/a | yes |
| <a name="input_metric_type"></a> [metric\_type](#input\_metric\_type) | アラートをトリガーするCloud Monitoringメトリックのタイプ。（例: 'logging.googleapis.com/log\_entry\_count'） | `string` | n/a | yes |
| <a name="input_monitored_project_id"></a> [monitored\_project\_id](#input\_monitored\_project\_id) | 監視対象となるリソースが存在するGCPプロジェクトのID。 | `string` | n/a | yes |
| <a name="input_notification_channel_ids"></a> [notification\_channel\_ids](#input\_notification\_channel\_ids) | アラート通知を送信するCloud Monitoring通知チャネルのIDリスト。 | `list(string)` | `[]` | no |
| <a name="input_scoping_project_id"></a> [scoping\_project\_id](#input\_scoping\_project\_id) | アラートポリシーを作成するモニタリングプロジェクトのID。（メトリクススコーププロジェクト） | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->