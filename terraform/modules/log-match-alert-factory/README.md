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
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | A user-assigned name for this resource. | `string` | n/a | yes |
| <a name="input_documentation"></a> [documentation](#input\_documentation) | Documentation for the alert policy, in Markdown format. | `string` | `"No documentation provided."` | no |
| <a name="input_filter"></a> [filter](#input\_filter) | A filter that identifies which log entries to monitor. | `string` | n/a | yes |
| <a name="input_monitored_project_id"></a> [monitored\_project\_id](#input\_monitored\_project\_id) | The ID of the project being monitored. | `string` | n/a | yes |
| <a name="input_notification_channel_ids"></a> [notification\_channel\_ids](#input\_notification\_channel\_ids) | A list of notification channel IDs to which notifications will be sent when the alert is triggered. | `list(string)` | `[]` | no |
| <a name="input_scoping_project_id"></a> [scoping\_project\_id](#input\_scoping\_project\_id) | The ID of the project in which the alert policy will be created (the scoping project). | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->