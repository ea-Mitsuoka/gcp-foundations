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
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_create_network"></a> [auto_create_network](#input_auto_create_network) | If true, the default network will be created. Defaults to false. | `bool` | `false` | no |
| <a name="input_folder_id"></a> [folder_id](#input_folder_id) | The folder ID to create the project in. If null, project will be created at the organization level. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input_labels) | A map of labels to assign to the project. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input_name) | The display name of the project. | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization_id](#input_organization_id) | The organization ID to create the project in. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project_id](#input_project_id) | The ID of the project. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_id"></a> [project_id](#output_project_id) | The ID of the created project. |
| <a name="output_project_name"></a> [project_name](#output_project_name) | The display name of the created project. |

<!-- END_TF_DOCS -->
