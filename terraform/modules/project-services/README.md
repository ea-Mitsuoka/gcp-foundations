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
| [google_project_service.services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_disable_on_destroy"></a> [disable\_on\_destroy](#input\_disable\_on\_destroy) | A flag to control the disable\_on\_destroy attribute of the google\_project\_service resource. | `bool` | `false` | no |
| <a name="input_project_apis"></a> [project\_apis](#input\_project\_apis) | A list of APIs to enable for the project. | `set(string)` | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project for which to enable APIs. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->