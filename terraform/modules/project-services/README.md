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
| [google_project_service.services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_disable_on_destroy"></a> [disable_on_destroy](#input_disable_on_destroy) | A flag to control the disable_on_destroy attribute of the google_project_service resource. | `bool` | `false` | no |
| <a name="input_project_apis"></a> [project_apis](#input_project_apis) | A list of APIs to enable for the project. | `set(string)` | `[]` | no |
| <a name="input_project_id"></a> [project_id](#input_project_id) | The ID of the project for which to enable APIs. | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
