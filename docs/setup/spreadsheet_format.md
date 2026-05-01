# プロジェクト構成用スプレッドシート (gcp-foundations.xlsx) の仕様

この基盤では、`gcp-foundations.xlsx` を Single Source of Truth (SSoT) とし、このExcelファイルに定義を行うことで、GCPのフォルダ、プロジェクト、ネットワーク（サブネット）、セキュリティ境界（VPC-SC）、組織ポリシーが自動生成される仕組みを採用しています。

## 配置場所

リポジトリのルートディレクトリに `gcp-foundations.xlsx` という名前で配置してください。未配置の状態で `make generate` を実行するとテンプレートが自動作成されます。

______________________________________________________________________

## シート定義

以下の7つのシートを使用して構成を定義します。

### 1. `resources` シート

GCPの階層構造（フォルダ・プロジェクト）と、それぞれの基本設定を定義します。

| 列名 (Header) | 型 | 説明 | 設定例 |
| :--- | :--- | :--- | :--- |
| **resource_type** | 文字列 | `folder` または `project` | `folder`, `project` |
| **parent_name** | 文字列 | 親要素名。組織直下は `organization_id` | `organization_id`, `production` |
| **resource_name** | 文字列 | フォルダ名、またはアプリ名（例: `prd-app-01`） | `production`, `prd-app-01` |
| **owner** | 文字列 | リソースの所有者（メールアドレス）。プロジェクトのラベルとして付与されます。 | `lead-dev@example.com` |
| **budget_amount** | 数値 | プロジェクトの月額予算。0より大きい場合、予算アラートが自動作成されます。 | `1000` |
| **budget_alert_emails** | 文字列 | 予算超過時の追加の通知先（カンマ区切り）。 | `finance@example.com` |
| **shared_vpc** | 文字列 | 使用する共有VPCサブネット名。※`folder`の場合は無視されます。 | `prd-subnet-01` |
| **vpc_sc** | 文字列 | 所属させるVPC-SC境界名。※`folder`の場合は無視されます。 | `default_perimeter` |
| **central_monitoring** | ブール値 | **中央監視の対象**とするか（Monitoringプロジェクトからの閲覧許可）。 | `TRUE`, `FALSE` |
| **central_logging** | ブール値 | **中央ログ集約の対象**とするか（LogSinkプロジェクトへの転送許可）。 | `TRUE`, `FALSE` |
| **org_tags** | 文字列 | 組織レベルのタグ。`キー/値` 形式で、複数ある場合はカンマ区切り。 | `environment/production, cost_center/123` |

### 2. `tag_definitions` シート (新規)

組織全体で使用可能なタグの「キー」と、セットできる「値（選択肢）」を定義します。GCP のタグはラベルと異なり、事前に定義された値以外はセットできないため、このシートでの定義が必須です。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **tag_key** | タグの一意なキー名 | `environment`, `cost_center` |
| **allowed_values** | そのキーにセット可能な値のリスト（カンマ区切り） | `production, development, sandbox` |
| **description** | タグの用途説明 | `環境種別 (Prod/Dev/Stg)` |

> **💡 タグ（Tags）のメリット**: 組織ポリシーの条件として使用できるため、「このタグが付いているプロジェクトのみ特定の制限を解除する」といった高度な統制が可能です。

### 3. `shared_vpc_subnets` シート

共有VPCホストプロジェクト内に作成するサブネットを定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **host_project_env** | どのホスト環境（`prod` / `dev`）に作成するか | `prod` |
| **subnet_name** | サブネットの一意な名前（`resources`シートで参照） | `prd-subnet-01` |
| **region** | 作成リージョン | `asia-northeast1` |
| **ip_cidr_range** | IP範囲 | `10.0.1.0/24` |

### 4. `vpc_sc_perimeters` シート

VPC Service Controls のサービス境界を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **perimeter_name** | 境界の一意な名前（`resources`シートで参照） | `default_perimeter` |
| **title** | 境界の表示名 | `Default Security Perimeter` |
| **restricted_services** | 保護対象のAPIサービス（カンマ区切り） | `storage.googleapis.com, bigquery.googleapis.com` |

### 5. `vpc_sc_access_levels` シート

境界内へのアクセスを許可する条件（アクセスレベル）を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **access_level_name** | アクセスレベルの一意な名前 | `office_ip_only` |
| **ip_subnetworks** | 許可するIP範囲（カンマ区切り） | `1.2.3.4/32` |
| **members** | 許可するユーザー/サービスアカウント（カンマ区切り） | `user:admin@example.com` |

### 6. `org_policies` シート

フォルダやプロジェクトに対して強制または許可する「組織ポリシー」を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **target_name** | 適用先リソース名（`organization_id` または `resources`シートで定義した名称） | `organization_id`, `shared`, `prd-app-01` |
| **policy_id** | ポリシーの名前（ID） | `compute.disableExternalIPProxy` |
| **enforce** | 強制するかどうか（ブール値。TRUEで制限有効） | `TRUE`, `FALSE` |
| **allow_list** | 許可リスト（カンマ区切り。ロケーション制限等で使用） | `asia-northeast1`, `us-central1` |

### 7. `notifications` シート

モニタリングアラートの通知先（メールアドレス等）を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **alert_name** | アラートの識別名（`alert_definitions`シートと紐付け） | `error_log_alert` |
| **user_email** | 通知先のメールアドレス | `admin@example.com` |
| **receive_alerts** | 通知を受け取るか（ブール値。TRUEで有効） | `TRUE`, `FALSE` |

### 8. `alert_definitions` シート

ログベースのアラート（Error検知等）の条件を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **alert_name** | アラートの一意な名前（`notifications`シートで参照） | `error_log_alert` |
| **alert_display_name** | コンソールに表示されるアラート名 | `Error Log Alert` |
| **metric_filter** | ログをフィルタリングするクエリ | `severity="ERROR"` |
| **alert_documentation** | アラート通知に含まれるドキュメント/説明 | `Documentation for error log alert` |

### 9. `log_sinks` シート

組織全体で集約するログの抽出条件と、宛先リソース（BigQuery データセットまたは GCS バケット）を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **log_type** | ログの分類名（`locals.tf` のマッピングで使用） | `管理アクティビティ監査ログ` |
| **filter** | ログを抽出するクエリフィルタ | `protoPayload.methodName:*` |
| **destination_type** | 宛先の種類（`BigQuery` または `Cloud Storage`） | `BigQuery` |
| **destination_parent** | 宛先リソース名のベース（データセット名など） | `audit_logs` |
| **retention_days** | ログの保持期間（日単位） | `365` |

### 10. リージョン設定の整合性と挙動

`common.tfvars` に定義する `gcp_region` と、Excel の `shared_vpc_subnets` シートに定義する `region` は、システム的に**独立したパラメータ**です。

| 項目 | 定義場所 | 主な用途 |
| :--- | :--- | :--- |
| **デフォルトリージョン** | `common.tfvars` (`gcp_region`) | ログ集約 (BQ/GCS)、監視等の組織共通リソースの配置場所。 |
| **サブネットリージョン** | Excel (`region` 列) | 各サブネットが物理的に作成される場所。 |

#### 💡 不整合はエラーになるか？

**結論から言えば、エラーにはなりません。** GCP はグローバルな VPC 構造を持つため、共通基盤を東京 (`asia-northeast1`) に置きつつ、サブネットを大阪 (`asia-northeast2`) や米国 (`us-central1`) に作成することは、標準的なマルチリージョン構成として許容されます。

#### ⚠️ 運用の注意点

システム的なエラーは起きませんが、以下の点に留意してください。

1. **組織ポリシーの制約**: `org_policies` シートでリソースの場所制限 (`gcp.resourceLocations`) を有効にしている場合、Excel で指定したリージョンが許可リストに含まれていないと、デプロイ時にポリシー違反で停止します。
1. **コストとレイテンシ**: 共通基盤（ログ送信先等）とサブネットが地理的に離れている場合、リージョン間データ転送コストやネットワークレイテンシが発生します。
1. **入力の徹底**: Excel の `region` が空欄の場合、不完全な Terraform コードが生成されエラーの原因となります。

特段の理由がない限り、**Excel の `region` も `common.tfvars` で指定したメインリージョンに合わせておくこと**が、最もシンプルで管理しやすい構成となります。

### 11. 自動バリデーションの詳細仕様

`make generate` を実行した際、スクリプトは以下の項目を技術的に検証します。一つでも違反がある場合、Terraform ファイルの生成は行われず、エラー一覧が表示されて停止します。

#### 11.1 命名規則のチェック (Naming Conventions)

GCP のリソース制限に基づき、以下の正規表現でチェックを行います。

- **プロジェクト名**: `4-30文字`, `小文字英数字`, `ハイフンのみ`。先頭は英字、末尾は英数字である必要があります。
- **フォルダ名**: `1-30文字`, `英数字`, `ハイフン`, `スペース` が使用可能です。

#### 11.2 階層構造の整合性 (Hierarchy Integrity)

- **親リソースの存在確認**: `parent_name` に指定されたフォルダが、同シート内で定義されているか、または組織直下 (`organization_id`) であるかを検証します。
- **循環参照の防止**: 自分自身を親フォルダに指定していないか（無限ループの防止）をチェックします。
- **リソース名の重複**: フォルダとプロジェクトを跨いで、同一のリソース名が定義されていないか（一意性）を検証します。

#### 11.3 ネットワーク設計の検証 (Network Validation)

- **CIDR 形式チェック**: `ip_cidr_range` が正しい CIDR 形式（例: `10.0.0.0/24`）であるかを検証します。
- **ホストビットの検証**: ネットワークアドレスとして正しくない入力（例: `10.0.1.5/24` などホスト部が含まれる）を検知します。
- **CIDR 重複チェック**: 定義されたすべてのサブネット間で、IP 範囲が重複（オーバーラップ）していないかを検証します。

#### 11.4 外部参照の整合性

- **Shared VPC 参照**: プロジェクトが使用する `shared_vpc` サブネットが、`shared_vpc_subnets` シートに実在するかを検証します。
- **VPC-SC 参照**: プロジェクトが所属する `vpc_sc` 境界が、`vpc_sc_perimeters` シートに実在するかを検証します。
- **アラート通知参照**: `notifications` シートで指定された `alert_name` が、`alert_definitions` シートに定義されているかを検証します。

______________________________________________________________________

## 💡 運用のポイント

### 1. 名前による紐付け

`resources` シートの `shared_vpc` や `vpc_sc` 列には、他のシートで定義した「名前（一意な識別子）」を記述します。これにより、プロジェクトが正しいサブネットや境界に自動的に紐付けられます。

#### 💡 フォルダ指定時の注意

`resource_type` が `folder` の場合、以下の列に値を入力しても自動生成エンジンによって無視されます。

- `shared_vpc`
- `vpc_sc`
- `central_monitoring`
- `central_logging`

これらはプロジェクト単位の操作を前提とした設定項目であるため、フォルダ作成時には `parent_name` と `resource_name` のみが使用されます。

### 2. 中央監視・ログ集約フラグの挙動

`resources` シートの `central_logging` および `central_monitoring` 列の挙動には以下の特性があります。

#### 中央ログ集約フラグ (`central_logging`)

- **挙動**: `FALSE` にしても **組織全体の監査ログ収集は停止しません**。
- **理由**: セキュリティ統制のため、監査ログ等の収集は「組織シンク」レベルで一括設定されています。
- **用途**: 主にプロジェクトに付与されるラベル (`central_logging: true/false`) や、管理台帳上の目印として使用します。プロジェクト個別のログ（アプリケーションログ等）を中央に送るかどうかの制御に使用されます。

#### 中央監視フラグ (`central_monitoring`)

- **挙動**: `FALSE` にすると **中央監視プロジェクトからの可視性が失われます**。
- **詳細**: 中央監視プロジェクトのサービスアカウントに対して、対象プロジェクトへのメトリクス読み取り権限（IAM）の付与がスキップされます。
- **結果**: 中央ダッシュボードや組織レベルのアラート通知にデータが現れなくなります。検証用の使い捨てプロジェクトなどでアラートノイズを減らしたい場合に `FALSE` を設定します。

### 3. 組織ポリシーの段階的な適用 (Migration Friendly)

既存のプロジェクトを組織へ移行する場合など、初期状態でポリシーが適用されていると移行がブロックされることがあります。

- **`terraform/common.tfvars` の `enable_org_policies`**:
  - `false` (デフォルト): 組織ポリシーは一切適用されません。移行作業時に推奨されます。
  - `true`: Excel で定義されたポリシーが有効化されます。

### 4. API 管理の委譲 (Separation of Concerns)

本基盤では、アプリケーションプロジェクト内部の API 有効化は現場の IaC または手動運用に委譲しています。

- **理由**: 基盤チームをボトルネックにせず、開発速度を最大化するため。
- **基盤の責務**: 「プロジェクト（箱）の作成」「共有VPCへの接続」「VPC-SC境界への追加」「管理用IAM権限の付与」までを確実に実行します。
- **現場の責務**: アプリケーションに必要な API の有効化およびリソースの作成。

### 5. 型変換の自動化

スクリプト（`make generate`）が、Excel上の真偽値やカンマ区切りの文字列を、Terraform が解釈可能な正しいデータ型に自動変換して出力します。

### 6. 入力支援とバリデーション

ヒューマンエラーを最小限にするため、以下の機能が備わっています。

- **プルダウンメニュー**: 主要な列にはデータ入力規則が設定されており、選択肢（folder/project, TRUE/FALSE 等）から選ぶことでタイポを防止できます。
- **整合性チェック**: `make generate` 実行時に、リソース名の重複、存在しない親フォルダの指定、必須項目の未入力などを自動検証し、問題があればエラーメッセージを表示して停止します。

______________________________________________________________________

## 反映の手順

1. `gcp-foundations.xlsx` を編集し、保存します。
1. 以下のコマンドを実行して、Excel の定義を Terraform コードに変換します。
   ```bash
   make generate
   ```
1. 変更内容をデプロイします。
   ```bash
   make deploy
   ```
