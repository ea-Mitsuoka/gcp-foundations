# regoファイルの実装例

.regoファイルは、Terraformと組み合わせることで「ポリシー・アズ・コード (Policy as Code)」を実現し、安全で統制の取れたインフラ管理を自動化するための強力なツールです。

## .rego ファイルのメリット

- 予防: ルール違反のインフラが作られてしまうのを未然に防ぎます。後から見つけて修正するより、ずっと安全で効率的です。
- 自動化: 人間の目によるレビューでは見逃しがちな細かいルールを、自動で一貫してチェックできます。
- 柔軟性: ラベル規約だけでなく、「インスタンスの命名規則」「セキュリティグループで危険なポートが開いていないか」「特定のリージョンでしかリソースを作成できないようにする」など、組織のあらゆるセキュリティ・ガバナンスルールをコードとして定義できます。c:wq

## よくある設定 (Common Settings)

多くの組織で基本として導入される、一般的なガバナンスルールです。

### \#\#\# ① 必須ラベルの徹底

すべてのリソースに特定のラベル（`env`と`owner`）が付与されていることを強制します。

```rego
package gcp.policies

# 必須ラベルのリストを定義
required_labels = {"env", "owner"}

# denyルール：一つでも違反があればエラーメッセージを返す
deny[msg] {
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
```

-----

### \#\#\# ② 命名規則の強制

すべてのリソース名に、組織で決められたプレフィックス（例: `my-org-`）が付いていることを保証します。

```rego
package gcp.policies

# denyルール
deny[msg] {
  some change in input.resource_changes
  change.change.actions[_] in ["create"] # 新規作成時のみチェック

  # リソース名を取得（"name"属性がないリソースは無視）
  resource_name := change.change.after.name
  
  # プレフィックスで始まっていない場合...
  not startswith(resource_name, "my-org-")

  # エラーメッセージを生成
  msg := sprintf("リソース '%s' の名前 '%s' は 'my-org-'で始まる必要があります", [change.address, resource_name])
}
```

-----

## 厳重な設定 (Strict Settings)

セキュリティやコンプライアンス要件が厳しい組織で採用される、より強力なルールです。

### \#\#\# ① パブリックIPアドレスの禁止

意図しない外部公開を防ぐため、VMインスタンスにパブリックIPが付与されることを原則として禁止します。

```rego
package gcp.policies

# denyルール
deny[msg] {
  some change in input.resource_changes
  change.type == "google_compute_instance" # GCEインスタンスのみ対象
  change.change.actions[_] in ["create", "update"]

  # ネットワークインターフェースの設定をループでチェック
  some network_interface in change.change.after.network_interface
  
  # "access_config"ブロックが存在する場合、パブリックIPが設定されていると判断
  # （"nat_ip"の有無でより厳密にチェックすることも可能）
  network_interface.access_config

  # エラーメッセージを生成
  msg := sprintf("GCEインスタンス '%s' にパブリックIPを付与することは禁止されています", [change.address])
}
```

-----

### \#\#\# ② GCSバケットの均一なバケットレベルアクセスの強制

GCSバケットのアクセス制御をシンプルにし、意図せぬ公開を防ぐためのベストプラクティスを強制します。

```rego
package gcp.policies

# denyルール
deny[msg] {
  some change in input.resource_changes
  change.type == "google_storage_bucket" # GCSバケットのみ対象
  change.change.actions[_] in ["create", "update"]

  # "uniform_bucket_level_access"がtrueに設定されていない場合...
  not change.change.after.uniform_bucket_level_access == true
  
  # エラーメッセージを生成
  msg := sprintf("GCSバケット '%s' では、均一なバケットレベルアクセス(uniform_bucket_level_access)を有効にする必要があります", [change.address])
}
```

-----

## その他例外的な設定 (Exceptional Settings)

ルールを強制しつつ、特定のケースを許容するための、より実践的なルールです。

### \#\#\# ① 特定リソースをルールから除外（許可リスト）

「パブリックIPは原則禁止だが、踏み台サーバーだけは許可する」といった例外を設けます。

```rego
package gcp.policies

# パブリックIPを許可するリソースのアドレスをリストで定義
public_ip_allowlist = {
  "google_compute_instance.bastion_host",
}

# denyルール
deny[msg] {
  some change in input.resource_changes
  change.type == "google_compute_instance"
  change.change.actions[_] in ["create", "update"]
  
  # ★★★ 例外条件：許可リストに含まれていないリソースのみをチェック対象とする ★★★
  not public_ip_allowlist[change.address]

  some network_interface in change.change.after.network_interface
  network_interface.access_config

  msg := sprintf("GCEインスタンス '%s' にパブリックIPを付与することは禁止されています（許可リスト対象外）", [change.address])
}
```

-----

### \#\#\# ② 環境（envラベル）に応じてルールを切り替え

「開発環境（dev）では大きいVMインスタンスも許可するが、本番環境（prod）ではコスト最適化されたインスタンスしか許可しない」といった、環境に応じた動的なルールです。

```rego
package gcp.policies

# 本番環境で許可するインスタンスタイプのリスト
prod_allowed_machine_types = {"e2-medium", "e2-small"}

# denyルール
deny[msg] {
  some change in input.resource_changes
  change.type == "google_compute_instance"
  change.change.actions[_] in ["create", "update"]
  
  # リソースのラベルから環境(env)を取得
  labels := change.change.after.labels
  
  # ★★★ 条件分岐：envラベルが"prod"の場合のみ、このルールを適用 ★★★
  labels.env == "prod"

  # インスタンスののマシンタイプを取得
  machine_type := change.change.after.machine_type
  
  # 許可リストに含まれていない場合...
  not prod_allowed_machine_types[machine_type]

  msg := sprintf("本番環境のインスタンス '%s' では許可されていないマシンタイプ '%s' が指定されています", [change.address, machine_type])
}
```
