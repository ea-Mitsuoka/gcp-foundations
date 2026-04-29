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
  deletion_policy     = var.deletion_protection ? "PREVENT" : "DELETE"

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
#   source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=535a37e77566e68ab35b1f5266cb1872405f15a2"
#   # domain-com-<project_name>にするならこちら
#   # source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=535a37e77566e68ab35b1f5266cb1872405f15a2"
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

# 予算通知用のメールチャネルを作成 (通知先と管理プロジェクトの両方が指定されている場合のみ)
resource "google_monitoring_notification_channel" "budget_emails" {
  for_each     = var.monitoring_project_id != null ? toset(var.budget_alert_emails) : []
  project      = var.monitoring_project_id
  display_name = "Budget Alert Email - ${each.key}"
  type         = "email"
  labels = {
    email_address = each.key
  }
}

# 予算アラートの設定 (予算が0より大きい場合のみ作成)
resource "google_billing_budget" "budget" {
  count = var.budget_amount > 0 && var.billing_account != null ? 1 : 0

  billing_account = var.billing_account
  display_name    = "Monthly Budget Alert - ${google_project.this.name}"

  budget_filter {
    projects = ["projects/${google_project.this.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = var.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    # 請求先アカウント管理者およびコスト管理者への通知を維持
    iam_threshold_defined_amount_updates = true
    
    # Excelで指定された追加のメールアドレスへの通知チャネルを紐付け
    monitoring_notification_channels = [
      for channel in google_monitoring_notification_channel.budget_emails : channel.name
    ]
  }
}
