<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement_google) | ~> 6.48.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement_google-beta) | ~> 6.48.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider_google) | 6.48.0 |
| <a name="provider_terraform"></a> [terraform](#provider_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_project"></a> [project](#module_project) | ../project-factory | n/a |

## Resources

| Name | Type |
|------|------|
| [google_access_context_manager_service_perimeter_resource.service_perimeter_resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/access_context_manager_service_perimeter_resource) | resource |
| [google_compute_shared_vpc_service_project.service_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_service_project) | resource |
| [google_compute_subnetwork_iam_member.subnet_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork_iam_member) | resource |
| [google_compute_subnetwork_iam_member.subnet_user_compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork_iam_member) | resource |
| [google_monitoring_monitored_project.central_monitoring_registration](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_monitored_project) | resource |
| [google_project_service.compute_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_tags_tag_binding.project_tags](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/tags_tag_binding) | resource |
| [terraform_data.variable_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [google_organization.org](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/organization) | data source |
| [terraform_remote_state.folders](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.organization](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.vpc_host](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_name"></a> [app_name](#input_app_name) | The name of the application. | `string` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing_account_id](#input_billing_account_id) | The billing account ID. | `string` | `null` | no |
| <a name="input_budget_alert_emails"></a> [budget_alert_emails](#input_budget_alert_emails) | The list of emails to receive budget alerts. | `list(string)` | `[]` | no |
| <a name="input_budget_amount"></a> [budget_amount](#input_budget_amount) | The budget amount for the project. | `number` | `0` | no |
| <a name="input_budget_threshold_percents"></a> [budget_threshold_percents](#input_budget_threshold_percents) | Budget alert threshold percentages (e.g. [0.5, 0.9, 1.0] = 50%/90%/100%). | `list(number)` | <pre>[<br/>  0.5,<br/>  0.9,<br/>  1<br/>]</pre> | no |
| <a name="input_central_logging"></a> [central_logging](#input_central_logging) | Whether to enable central logging. | `bool` | `true` | no |
| <a name="input_central_monitoring"></a> [central_monitoring](#input_central_monitoring) | Whether to enable central monitoring. | `bool` | `true` | no |
| <a name="input_deletion_protection"></a> [deletion_protection](#input_deletion_protection) | Whether to enable deletion protection. | `bool` | `true` | no |
| <a name="input_enable_org_policies"></a> [enable_org_policies](#input_enable_org_policies) | Global switch to enable Organization Policies. | `bool` | `false` | no |
| <a name="input_enable_shared_vpc"></a> [enable_shared_vpc](#input_enable_shared_vpc) | Global switch to enable Shared VPC. | `bool` | `false` | no |
| <a name="input_enable_tags"></a> [enable_tags](#input_enable_tags) | Global switch to enable Organization Tags. | `bool` | `false` | no |
| <a name="input_enable_vpc_sc"></a> [enable_vpc_sc](#input_enable_vpc_sc) | Global switch to enable VPC Service Controls. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input_environment) | The environment name (prod, stag, dev). | `string` | n/a | yes |
| <a name="input_existing_project_id"></a> [existing_project_id](#input_existing_project_id) | 既存プロジェクト採用(adopt)モード。空でなければ create_project=false でこの既存IDを採用する（命名規則 <prefix>-<app_name> に非準拠なプロジェクトを管理下に置くため）。実体は terraform import で取り込む。 | `string` | `""` | no |
| <a name="input_folder_id"></a> [folder_id](#input_folder_id) | The folder ID to place the project in. | `string` | `""` | no |
| <a name="input_gcs_backend_bucket"></a> [gcs_backend_bucket](#input_gcs_backend_bucket) | The GCS bucket name for Terraform state. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input_labels) | The labels to apply to the project. | `map(string)` | `{}` | no |
| <a name="input_mgmt_project_id"></a> [mgmt_project_id](#input_mgmt_project_id) | The management project ID. | `string` | `null` | no |
| <a name="input_org_tags"></a> [org_tags](#input_org_tags) | The list of organization tags (key/value format). | `list(string)` | `[]` | no |
| <a name="input_organization_domain"></a> [organization_domain](#input_organization_domain) | The organization domain name. | `string` | n/a | yes |
| <a name="input_project_id_prefix"></a> [project_id_prefix](#input_project_id_prefix) | The prefix for project IDs. | `string` | n/a | yes |
| <a name="input_shared_vpc_env"></a> [shared_vpc_env](#input_shared_vpc_env) | The shared VPC environment (prod, dev, none). | `string` | `"none"` | no |
| <a name="input_shared_vpc_subnet"></a> [shared_vpc_subnet](#input_shared_vpc_subnet) | The name of the shared VPC subnet. | `string` | `""` | no |
| <a name="input_terraform_service_account_email"></a> [terraform_service_account_email](#input_terraform_service_account_email) | The email of the Terraform service account. | `string` | n/a | yes |
| <a name="input_vpc_sc"></a> [vpc_sc](#input_vpc_sc) | The name of the VPC-SC perimeter. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_id"></a> [project_id](#output_project_id) | The ID of the created project. |
| <a name="output_project_number"></a> [project_number](#output_project_number) | The numeric ID of the created project. |

<!-- END_TF_DOCS -->
