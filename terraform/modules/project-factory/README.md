<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.5.0 |
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
| [google_billing_budget.budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |
| [google_monitoring_notification_channel.budget_emails](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_create_network"></a> [auto_create_network](#input_auto_create_network) | If true, the default network will be created. Defaults to true. | `bool` | `true` | no |
| <a name="input_billing_account"></a> [billing_account](#input_billing_account) | The billing account ID to associate the budget with. Required if budget_amount > 0. | `string` | `null` | no |
| <a name="input_budget_alert_emails"></a> [budget_alert_emails](#input_budget_alert_emails) | List of additional email addresses to receive budget alerts. | `list(string)` | `[]` | no |
| <a name="input_budget_amount"></a> [budget_amount](#input_budget_amount) | The monthly budget amount for the project. If 0, no budget alert is created. | `number` | `0` | no |
| <a name="input_create_project"></a> [create_project](#input_create_project) | true(既定)は新規作成フロー。false の場合は既存プロジェクトの採用(adopt)モードとなり、project_id_override の既存IDを採用する（実体は terraform import で state に取り込む）。 | `bool` | `true` | no |
| <a name="input_deletion_protection"></a> [deletion_protection](#input_deletion_protection) | Whether or not to protect the project from deletion. Internally mapped to google_project's deletion_policy (PREVENT/DELETE). Default is true. | `bool` | `true` | no |
| <a name="input_folder_id"></a> [folder_id](#input_folder_id) | The folder ID to create the project in. If null, project will be created at the organization level. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input_labels) | A map of labels to assign to the project. | `map(string)` | `{}` | no |
| <a name="input_monitoring_project_id"></a> [monitoring_project_id](#input_monitoring_project_id) | The ID of the project where notification channels will be created (usually the management or central monitoring project). | `string` | `null` | no |
| <a name="input_name"></a> [name](#input_name) | The display name of the project. | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization_id](#input_organization_id) | The organization ID to create the project in. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project_id](#input_project_id) | The ID of the project. | `string` | n/a | yes |
| <a name="input_project_id_override"></a> [project_id_override](#input_project_id_override) | 採用(adopt)モードで使用する既存プロジェクトID。create_project=false かつ空文字でない場合に var.project_id の代わりに使用する。 | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_id"></a> [project_id](#output_project_id) | The ID of the created project. |
| <a name="output_project_name"></a> [project_name](#output_project_name) | The display name of the created project. |
| <a name="output_project_number"></a> [project_number](#output_project_number) | The numeric ID of the created project. |

<!-- END_TF_DOCS -->
