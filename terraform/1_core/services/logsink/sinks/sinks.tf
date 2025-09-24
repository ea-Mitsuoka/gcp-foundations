# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
resource "google_logging_organization_sink" "dynamic_sinks" {
  for_each = local.sink_configs

  provider = google-beta
  name     = "org-${replace(each.key, "_", "-")}-sink"
  org_id   = data.google_organization.org.org_id
  filter   = each.value.filter

  # 宛先の種類に応じて、動的に作成された宛先リソースを参照
  destination = lower(each.value.destination_type) == "bigquery" ? "bigquery.googleapis.com/projects/${data.terraform_remote_state.project.outputs.project_id}/datasets/${google_bigquery_dataset.dynamic_datasets[each.value.destination_parent].dataset_id}" : "storage.googleapis.com/${google_storage_bucket.dynamic_buckets[each.value.destination_parent].name}"

  # BigQueryの場合のみ bigquery_options を設定
  dynamic "bigquery_options" {
    for_each = lower(each.value.destination_type) == "bigquery" ? [1] : []
    content {
      use_partitioned_tables = true
    }
  }
}
