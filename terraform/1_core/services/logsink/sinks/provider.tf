provider "google" {
  # このTerraformが操作する対象のプロジェクトID
  project = data.terraform_remote_state.project.outputs.project_id
}

provider "google-beta" {
  # googleプロバイダーと同じプロジェクトIDを指定
  project = data.terraform_remote_state.project.outputs.project_id
}