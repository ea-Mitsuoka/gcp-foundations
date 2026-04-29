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

  # プロジェクトリソースのみを対象にラベルを強制する
  change.type == "google_project"

  # リソースの labels 属性を安全に取得
  labels := get_labels(change.change.after)

  # 必須ラベルのセットと、リソースに実際に付与されたラベルのセットを比較
  # (labels が空 {} の場合は provided_labels も空になる)
  provided_labels := {k | _ := labels[k]}
  missing_labels := required_labels - provided_labels

  # 足りないラベルが1つでもあれば（count > 0）...
  count(missing_labels) > 0

  # エラーメッセージを生成
  msg := sprintf("プロジェクト '%s' に必須ラベルがありません: %s", [change.address, missing_labels])
}

# labels 属性が null や未定義の場合に備え、安全に空のオブジェクトにフォールバックするヘルパー
get_labels(after) := labels if {
    labels := object.get(after, "labels", {})
    labels != null
} else := {}
