# プロジェクト構成用スプレッドシート (gcp_foundations.xlsx) の仕様

この基盤では、`gcp_foundations.xlsx` を Single Source of Truth (SSoT) とし、このExcelファイルに定義を行うことで、GCPのフォルダ、プロジェクト、ネットワーク（サブネット）、セキュリティ境界（VPC-SC）、組織ポリシーが自動生成される仕組みを採用しています。

## 配置場所

リポジトリのルートディレクトリに `gcp_foundations.xlsx` という名前で配置してください。未配置の状態で `make generate` を実行するとテンプレートが自動作成されます。

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
| **shared_vpc** | 文字列 | 使用する共有VPCサブネット名（後述のシートで定義したもの） | `prd-subnet-01` |
| **vpc_sc** | 文字列 | 所属させるVPC-SC境界名（後述のシートで定義したもの） | `default_perimeter` |
| **monitoring** | ブール値 | 監視対象とするか | `TRUE`, `FALSE` |
| **logging** | ブール値 | ログ集約対象とするか | `TRUE`, `FALSE` |
| **billing_linked** | ブール値 | 課金アカウントが手動でリンク済みか（TRUEでAPI有効化） | `TRUE`, `FALSE` |
| **project_apis** | 文字列 | 有効化したいAPI（カンマ区切り） | `compute.googleapis.com` |

### 2. `shared_vpc_subnets` シート

共有VPCホストプロジェクト内に作成するサブネットを定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **host_project_env** | どのホスト環境（`prod` / `dev`）に作成するか | `prod` |
| **subnet_name** | サブネットの一意な名前（`resources`シートで参照） | `prd-subnet-01` |
| **region** | 作成リージョン | `asia-northeast1` |
| **ip_cidr_range** | IP範囲 | `10.0.1.0/24` |

### 3. `vpc_sc_perimeters` シート

VPC Service Controls のサービス境界を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **perimeter_name** | 境界の一意な名前（`resources`シートで参照） | `default_perimeter` |
| **title** | 境界の表示名 | `Default Security Perimeter` |
| **restricted_services** | 保護対象のAPIサービス（カンマ区切り） | `storage.googleapis.com, bigquery.googleapis.com` |

### 4. `vpc_sc_access_levels` シート

境界内へのアクセスを許可する条件（アクセスレベル）を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **access_level_name** | アクセスレベルの一意な名前 | `office_ip_only` |
| **ip_subnetworks** | 許可するIP範囲（カンマ区切り） | `1.2.3.4/32` |
| **members** | 許可するユーザー/サービスアカウント（カンマ区切り） | `user:admin@example.com` |

### 5. `org_policies` シート

フォルダやプロジェクトに対して強制または許可する「組織ポリシー」を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **target_name** | 適用先リソース名（`organization_id` または `resources`シートで定義した名称） | `organization_id`, `shared`, `prd-app-01` |
| **policy_id** | ポリシーの名前（ID） | `compute.disableExternalIPProxy` |
| **enforce** | 強制するかどうか（ブール値。TRUEで制限有効） | `TRUE`, `FALSE` |
| **allow_list** | 許可リスト（カンマ区切り。ロケーション制限等で使用） | `asia-northeast1`, `us-central1` |

### 6. `notifications` シート

モニタリングアラートの通知先（メールアドレス等）を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **alert_name** | アラートの識別名（`alert_definitions`シートと紐付け） | `error_log_alert` |
| **user_email** | 通知先のメールアドレス | `admin@example.com` |
| **receive_alerts** | 通知を受け取るか（ブール値。TRUEで有効） | `TRUE`, `FALSE` |
| **project_id** | 通知対象のログが存在するプロジェクトID | `logsink-project-id` |

### 7. `alert_definitions` シート

ログベースのアラート（Error検知等）の条件を定義します。

| 列名 | 説明 | 例 |
| :--- | :--- | :--- |
| **alert_name** | アラートの一意な名前（`notifications`シートで参照） | `error_log_alert` |
| **alert_display_name** | コンソールに表示されるアラート名 | `Error Log Alert` |
| **metric_filter** | ログをフィルタリングするクエリ | `severity="ERROR"` |
| **alert_documentation** | アラート通知に含まれるドキュメント/説明 | `Documentation for error log alert` |

______________________________________________________________________

## 💡 運用のポイント

### 1. 名前による紐付け

`resources` シートの `shared_vpc` や `vpc_sc` 列には、他のシートで定義した「名前（一意な識別子）」を記述します。これにより、プロジェクトが正しいサブネットや境界に自動的に紐付けられます。

### 2. 組織ポリシーの段階的な適用 (Migration Friendly)

既存のプロジェクトを組織へ移行する場合など、初期状態でポリシーが適用されていると移行がブロックされることがあります。

- **`terraform/common.tfvars` の `enable_org_policies`**:
  - `false` (デフォルト): 組織ポリシーは一切適用されません。移行作業時に推奨されます。
  - `true`: Excel で定義されたポリシーが有効化されます。

### 3. 型変換の自動化

スクリプト（`make generate`）が、Excel上の真偽値やカンマ区切りの文字列を、Terraform が解釈可能な正しいデータ型に自動変換して出力します。

### 4. 入力支援とバリデーション

ヒューマンエラーを最小限にするため、以下の機能が備わっています。

- **プルダウンメニュー**: 主要な列にはデータ入力規則が設定されており、選択肢（folder/project, TRUE/FALSE 等）から選ぶことでタイポを防止できます。
- **整合性チェック**: `make generate` 実行時に、リソース名の重複、存在しない親フォルダの指定、必須項目の未入力などを自動検証し、問題があればエラーメッセージを表示して停止します。

______________________________________________________________________

## 反映の手順

1. `gcp_foundations.xlsx` を編集し、保存します。
1. 以下のコマンドを実行して、Excel の定義を Terraform コードに変換します。
   ```bash
   make generate
   ```
1. 変更内容をデプロイします。
   ```bash
   make deploy
   ```
