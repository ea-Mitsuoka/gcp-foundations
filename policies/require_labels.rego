package terraform.validation

import rego.v1

# 必須ラベルの定義（環境、所有者、アプリ名）
required_labels := {"env", "owner", "app"}

# プロジェクト作成・更新時に必須ラベルが欠如している場合、デプロイをブロックする
deny contains msg if {
    # 変更されるリソースをイテレーション
    some resource in input.resource_changes
    
    # 対象を GCP プロジェクトのリソースに限定
    resource.type == "google_project"
    
    # 削除アクションは除外
    some action in resource.change.actions
    action != "delete"

    # labels 属性を取得（nullまたは未定義の場合は空オブジェクトとして扱う）
    labels := object.get(resource.change.after, "labels", {})
    
    # 必須ラベルの中で、設定されていないものを特定
    missing := {l | some l in required_labels; not labels[l]}
    count(missing) > 0
    
    # エラーメッセージを生成
    msg := sprintf("GCP Project '%s' is missing required labels: %v", [resource.address, missing])
}
