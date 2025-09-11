data "external" "org_name" {
  program = ["bash", "${local.scripts_dir}/get-organization-name.sh"]
}

data "external" "org_id" {
  program = ["bash", "${local.scripts_dir}/get-organization-id.sh"]
}
