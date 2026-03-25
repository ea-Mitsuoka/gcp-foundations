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
| [google_project_iam_member.project_iam_bindings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_member"></a> [member](#input_member) | The member (user, service account, etc.) to whom the roles will be granted. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project_id](#input_project_id) | The ID of the project to which IAM permissions will be granted. | `string` | n/a | yes |
| <a name="input_roles"></a> [roles](#input_roles) | A list of IAM roles to grant to the member. | `set(string)` | `[]` | no |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
