# GCPプロジェクトの作成
resource "google_project" "this" {
  project_id = var.project_id
  name       = var.name
  org_id     = var.folder_id == null ? var.organization_id : null
  folder_id  = var.folder_id
  # billing_account はプロジェクト作成後に管理者アカウントで設定するため、ここでは定義しない
  # billing_account = var.billing_account
  labels              = { for k, v in var.labels : k => v if v != "" && v != null }
  auto_create_network = var.auto_create_network

  # 差分を無視するための設定を追加
  lifecycle {
    ignore_changes = [
      # billing_account属性への変更をTerraformの管理対象外にする
      billing_account,
    ]
  }
}

# 使い方
# # 外部モジュール（string_utils）の呼び出し
# module "string_utils" {
#   source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=54a758c"
#   # domain-com-<project_name>にするならこちら
#   # source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae09b1"
#   organization_name = var.organization_name # dataソースの代わりに変数から受け取る
#   env               = var.labels.env
#   app               = var.labels.app
# }

# # プロジェクトID用のランダムな接尾辞
# resource "random_id" "project_suffix" {
#   byte_length = 2
# }

# # GCPプロジェクトの作成
# resource "google_project" "this" {
#   project_id = "${var.organization_name}-${var.project_name}-${random_id.project_suffix.hex}"
#   name       = "${module.string_utils.sanitized_org_name}-${var.project_name}"
#   org_id     = var.organization_id # dataソースの代わりに変数から受け取る
#   # deletion_policy = "DELETE"  # ← PREVENT から変更

#   labels = { for k, v in var.labels : k => v if v != "" && v != null }

#   # billing_account はプロジェクト作成後に管理者アカウントで設定するため、ここでは定義しない
# }
