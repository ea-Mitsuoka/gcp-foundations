package gcp.policies

import rego.v1

# 必須ラベルのリストを定義
required_labels := {"env", "owner"}

# denyルール：一つでも違反があればエラーメッセージを返す
deny contains msg if {
  # Terraform planに含まれる全リソース変更をチェック
  some change in input.resource_changes

  # 作成(create)または更新(update)されるリソースのみを対象
  change.change.actions[_] in ["create", "update"]

  # リソースに"labels"属性が存在するか確認
  labels := change.change.after.labels

  # 必須ラベルのセットと、リソースに実際に付与されたラベルのセットを比較
  provided_labels := {k | labels[k]}
  missing_labels := required_labels - provided_labels

  # 足りないラベルが1つでもあれば（count > 0）...
  count(missing_labels) > 0

  # エラーメッセージを生成
  msg := sprintf("リソース '%s' に必須ラベルがありません: %s", [change.address, missing_labels])
}
