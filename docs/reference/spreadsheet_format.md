# プロジェクト構成用スプレッドシート (gcp_foundations.xlsx) の仕様

この基盤では、`gcp_foundations.xlsx` を Single Source of Truth (SSOT) とし、このExcelファイルに記入するだけで、新しいGCPのフォルダとプロジェクトが自動生成される仕組みを採用しています。

## 配置場所

リポジトリのルートディレクトリ（`domain.env` と同じ階層）に `gcp_foundations.xlsx` という名前で配置してください。（未配置の状態で `generate_resources.py` を実行するとテンプレートが自動作成されます）

## カラム（ヘッダー）定義

Excelの `resources` シートの「1行目」には必ず以下のヘッダー（列名）を定義してください。順不同ですが、名前は正確に一致させる必要があります。

| 列名 (Header) | 必須 | 型 | 説明 | 設定例 |
| :--- | :---: | :--- | :--- | :--- |
| **resource_type** | 必須 | 文字列 | `folder` または `project` を指定します。 | `folder`, `project` |
| **parent_name** | 必須 | 文字列 | 親となるフォルダ名。組織直下の場合は `organization_id` を指定します。 | `organization_id`, `production` |
| **resource_name** | 必須 | 文字列 | フォルダの表示名、またはプロジェクトのアプリケーション名（例: `prd-app-01`）。 | `shared`, `prd-app-01` |
| **shared_vpc** | 任意 | ブール値 | 共有VPCに参加するかどうか。`TRUE` の場合 `1_core` のホストプロジェクトに接続されます。 | `TRUE`, `FALSE` |
| **monitoring** | 任意 | ブール値 | Cloud Monitoringによる監視の対象とするか。 | `TRUE`, `FALSE` |
| **logging** | 任意 | ブール値 | ログシンク等による集約ログ収集の対象とするか。 | `TRUE`, `FALSE` |
| **billing_linked** | 必須 | ブール値 | 課金アカウントが手動でリンクされているか。`TRUE` の場合のみAPIが有効化されます。 | `FALSE`, `TRUE` |
| **project_apis** | 任意 | 文字列 | プロジェクトで有効化したいGCP APIのリスト（複数ある場合はカンマ区切り）。 | `compute.googleapis.com, run.googleapis.com` |

## 入力方法と具体例 (Input Methods & Examples)

`gcp_foundations.xlsx` は環境ごとに機密情報を一部含む可能性があるため、Gitリポジトリ（`.gitignore`）の管理対象外に設定されています。
初めて使用する際は、ルートディレクトリで `uv run terraform/scripts/generate_resources.py` を実行すると、自動的にテンプレートとなるExcelファイルが生成されます。

### 入力の基本ルール

- **シート名:** 必ず `resources` という名前のシートにデータを入力してください。
- **階層構造:** `folder` を定義し、その `resource_name` を子要素の `parent_name` に指定することで、GCP上のフォルダ構造を表現します。
- **ブール値:** `TRUE` / `FALSE` はExcelの真偽値（論理値）、または文字列として入力します。

### 具体例 (Example Data)

以下の表は、Excelに入力するデータの具体的なイメージです。

| resource_type | parent_name | resource_name | shared_vpc | vpc_sc | monitoring | logging | billing_linked | project_apis |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **folder** | `organization_id` | `shared` | FALSE | FALSE | FALSE | FALSE | FALSE | |
| **folder** | `shared` | `production` | FALSE | FALSE | FALSE | FALSE | FALSE | |
| **folder** | `shared` | `development` | FALSE | FALSE | FALSE | FALSE | FALSE | |
| **project** | `production` | `prd-app-01` | TRUE | TRUE | TRUE | TRUE | FALSE | `compute.googleapis.com,container.googleapis.com` |
| **project** | `development` | `dev-app-01` | TRUE | FALSE | TRUE | TRUE | FALSE | `compute.googleapis.com,run.googleapis.com` |
| **project** | `organization_id` | `standalone-proj`| FALSE | FALSE | TRUE | TRUE | FALSE | `storage.googleapis.com` |

#### 例の解説

1. **組織直下のフォルダ作成:** 1行目では、組織（`organization_id`）の直下に `shared` というフォルダを作成しています。
1. **入れ子のフォルダ作成:** 2行目・3行目では、作成した `shared` フォルダを親として、その中に `production` と `development` というフォルダを作成しています。
1. **プロジェクトの作成 (prd-app-01):** 4行目では、`production` フォルダの中に `prd-app-01` プロジェクトを作成します。`shared_vpc` や `vpc_sc` などを有効にし、GCEやGKEのAPIを有効化するリストを定義しています。
1. **Standalone プロジェクト:** 6行目のように、親フォルダを `organization_id` と指定すれば、フォルダに属さない組織直下のプロジェクトを作成することも可能です。

※ 注意: 初回作成時は必ず `billing_linked` を `FALSE` にしてください。手動で課金をリンクした後に `TRUE` に変更し、再実行することでAPIが有効化されます。

## 動作の仕組み

1. `terraform/scripts/deploy_all.sh` を実行した際、内部で `generate_resources.py` が呼び出されます。
1. スクリプトは `gcp_foundations.xlsx` の `resources` シートを走査し、以下の処理を行います。
   - `resource_type` が `folder` の場合: `terraform/3_folders/auto_folders.tf` を生成し、階層構造を含めたTerraformコードを出力します。
   - `resource_type` が `project` の場合: `terraform/4_projects/<resource_name>` ディレクトリを生成します。
1. `4_projects` では `example_project` から Terraformの構成ファイルがコピーされ、Excelの値が注入された `terraform.tfvars` が配置されます。
1. プロジェクトの環境名（`env`）は `resource_name` の接頭辞（`prd-`, `stg-`, `dev-`）から自動判定されます。
