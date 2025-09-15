# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

resource "google_monitoring_monitored_project" "monitored_projects" {
  # for_each を使い、取得したプロジェクトのリストからリソースを動的に作成
  # toset(...) でプロジェクトIDの重複をなくし、一意なセットに変換
  # if p.project_id != scoping_project_id で、スコーピングプロジェクト自身は対象から除外
  for_each = toset([
    for p in data.google_projects.all_projects.projects : p.project_id
    if p.project_id != data.terraform_remote_state.project.outputs.project_id
  ])

  # 指標スコープの指定
  metrics_scope = "projects/${data.terraform_remote_state.project.outputs.project_id}"

  # 監視対象となるプロジェクトID
  name = each.key
}
