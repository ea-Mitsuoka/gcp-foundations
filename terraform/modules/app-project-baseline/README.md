<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.48.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.48.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.48.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_project"></a> [project](#module\_project) | ../project-factory | n/a |

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
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | The name of the application. | `string` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | The billing account ID. | `string` | `null` | no |
| <a name="input_budget_alert_emails"></a> [budget\_alert\_emails](#input\_budget\_alert\_emails) | The list of emails to receive budget alerts. | `list(string)` | `[]` | no |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | The budget amount for the project. | `number` | `0` | no |
| <a name="input_central_logging"></a> [central\_logging](#input\_central\_logging) | Whether to enable central logging. | `bool` | `true` | no |
| <a name="input_central_monitoring"></a> [central\_monitoring](#input\_central\_monitoring) | Whether to enable central monitoring. | `bool` | `true` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection. | `bool` | `true` | no |
| <a name="input_enable_org_policies"></a> [enable\_org\_policies](#input\_enable\_org\_policies) | Global switch to enable Organization Policies. | `bool` | `false` | no |
| <a name="input_enable_shared_vpc"></a> [enable\_shared\_vpc](#input\_enable\_shared\_vpc) | Global switch to enable Shared VPC. | `bool` | `false` | no |
| <a name="input_enable_tags"></a> [enable\_tags](#input\_enable\_tags) | Global switch to enable Organization Tags. | `bool` | `false` | no |
| <a name="input_enable_vpc_sc"></a> [enable\_vpc\_sc](#input\_enable\_vpc\_sc) | Global switch to enable VPC Service Controls. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment name (prod, stag, dev). | `string` | n/a | yes |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The folder ID to place the project in. | `string` | `""` | no |
| <a name="input_gcs_backend_bucket"></a> [gcs\_backend\_bucket](#input\_gcs\_backend\_bucket) | The GCS bucket name for Terraform state. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | The labels to apply to the project. | `map(string)` | `{}` | no |
| <a name="input_mgmt_project_id"></a> [mgmt\_project\_id](#input\_mgmt\_project\_id) | The management project ID. | `string` | `null` | no |
| <a name="input_org_tags"></a> [org\_tags](#input\_org\_tags) | The list of organization tags (key/value format). | `list(string)` | `[]` | no |
| <a name="input_organization_domain"></a> [organization\_domain](#input\_organization\_domain) | The organization domain name. | `string` | n/a | yes |
| <a name="input_project_id_prefix"></a> [project\_id\_prefix](#input\_project\_id\_prefix) | The prefix for project IDs. | `string` | n/a | yes |
| <a name="input_shared_vpc_env"></a> [shared\_vpc\_env](#input\_shared\_vpc\_env) | The shared VPC environment (prod, dev, none). | `string` | `"none"` | no |
| <a name="input_shared_vpc_subnet"></a> [shared\_vpc\_subnet](#input\_shared\_vpc\_subnet) | The name of the shared VPC subnet. | `string` | `""` | no |
| <a name="input_terraform_service_account_email"></a> [terraform\_service\_account\_email](#input\_terraform\_service\_account\_email) | The email of the Terraform service account. | `string` | n/a | yes |
| <a name="input_vpc_sc"></a> [vpc\_sc](#input\_vpc\_sc) | The name of the VPC-SC perimeter. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the created project. |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The numeric ID of the created project. |
<!-- END_TF_DOCS -->