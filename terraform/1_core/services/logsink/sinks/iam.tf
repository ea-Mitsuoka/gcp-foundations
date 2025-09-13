resource "google_project_iam_member" "sink_writers" {
  for_each = google_logging_organization_sink.dynamic_sinks

  project = data.terraform_remote_state.project.outputs.project_id
  member  = each.value.writer_identity
  role    = strcontains(each.value.destination, "bigquery") ? "roles/bigquery.dataEditor" : "roles/storage.objectCreator"
}
