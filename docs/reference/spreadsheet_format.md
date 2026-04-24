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

## 動作の仕組み

1. `terraform/scripts/deploy_all.sh` を実行した際、内部で `generate_resources.py` が呼び出されます。
1. スクリプトは `gcp_foundations.xlsx` の `resources` シートを走査し、以下の処理を行います。
   - `resource_type` が `folder` の場合: `terraform/3_folders/auto_folders.tf` を生成し、階層構造を含めたTerraformコードを出力します。
   - `resource_type` が `project` の場合: `terraform/4_projects/<resource_name>` ディレクトリを生成します。
1. `4_projects` では `example_project` から Terraformの構成ファイルがコピーされ、Excelの値が注入された `terraform.tfvars` が配置されます。
1. プロジェクトの環境名（`env`）は `resource_name` の接頭辞（`prd-`, `stg-`, `dev-`）から自動判定されます。
