# GCPプロジェクトの作成
locals {
  # 採用(adopt)モード: create_project=false かつ project_id_override 指定時は既存プロジェクトIDを採用する
  # （実体は terraform import で state に取り込む）。create_project=true（既定）では従来どおり
  # var.project_id を使うため、既存プロジェクトの挙動は一切変わらない（後方互換）。
  effective_project_id = var.create_project ? var.project_id : (var.project_id_override != "" ? var.project_id_override : var.project_id)
}

resource "google_project" "this" {
  project_id = local.effective_project_id
  name       = var.name
  # "organizations/" や "folders/" が含まれていたら自動で取り除く防弾仕様
  org_id    = (var.folder_id == null || var.folder_id == "") ? replace(var.organization_id, "organizations/", "") : null
  folder_id = (var.folder_id == null || var.folder_id == "") ? null : replace(var.folder_id, "folders/", "")
  # billing_account はプロジェクト作成後に管理者アカウントで設定するため、ここでは定義しない
  billing_account     = var.billing_account
  labels              = { for k, v in var.labels : k => v if v != "" && v != null }
  auto_create_network = var.auto_create_network
  deletion_policy     = var.deletion_protection ? "PREVENT" : "DELETE"

  # 差分を無視するための設定を追加
  # 注: 採用(adopt)モードの import 直後は name/labels/deletion_policy 等で in-place 差分が出るが、
  #     lifecycle.ignore_changes は変数で動的化できない（Terraform 仕様）ため固定にしている。
  #     採用時の属性差分は import → plan レビュー → apply で吸収する運用（migration ガイド参照）。
  lifecycle {
    ignore_changes = [
      # 課金リンク(billing_account)は「作成時のみ設定」し、以後 TF は移動・解除しない。
      # これにより (1) billing_account=null（manual/手動運用）で既存リンクを解除しない、
      # (2) 採用(adopt)した既存プロジェクトの課金を勝手に付け替えない、を安全に実現する。
      # トレードオフ: 課金リンクのドリフトは TF では強制・検知しない（billing admin が別管理）。
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
  for_each     = (var.monitoring_project_id != null && var.budget_amount > 0 && var.billing_account != null) ? toset(var.budget_alert_emails) : []
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
    projects = ["projects/${google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = var.budget_amount
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_threshold_percents
    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    # 請求先アカウント管理者およびコスト管理者への通知を維持
    disable_default_iam_recipients = false

    # Excelで指定された追加のメールアドレスへの通知チャネルを紐付け
    monitoring_notification_channels = var.monitoring_project_id != null && length(var.budget_alert_emails) > 0 ? [
      for channel in google_monitoring_notification_channel.budget_emails : channel.name
    ] : null
  }
}
