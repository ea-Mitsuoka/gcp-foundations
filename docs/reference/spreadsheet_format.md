# docs/reference/spreadsheet_format.md

# プロジェクト構成用スプレッドシート (projects_config.xlsx) の仕様

この基盤では、`projects_config.xlsx` を Single Source of Truth (SSOT) とし、このExcelファイルに記入するだけで、新しいGCPプロジェクトが自動生成される仕組みを採用しています。

## 配置場所

リポジトリのルートディレクトリ（`domain.env` と同じ階層）に `projects_config.xlsx` という名前で配置してください。

## カラム（ヘッダー）定義

Excelの「1行目」には必ず以下のヘッダー（列名）を定義してください。順不同ですが、名前は正確に一致させる必要があります。

| 列名 (Header) | 必須 | 型 | 説明 | 設定例 |
| :--- | :---: | :--- | :--- | :--- |
| **app_name** | 必須 | 文字列 | アプリケーションやサービスの名前。作成されるディレクトリ名になります。 | `web-frontend`, `data-pipeline` |
| **env** | 必須 | 文字列 | 環境名。プロジェクトIDの一部になります。 | `dev`, `stag`, `prod` |
| **folder_id** | 任意 | 数値/文字列 | プロジェクトを配置するGCPのフォルダID。空欄の場合は組織直下に作成されます。 | `123456789012` |

## 動作の仕組み

1. `terraform/scripts/deploy_all.sh` を実行した際、内部で `generate_tfvars.py` が呼び出されます。
1. スクリプトは `projects_config.xlsx` の2行目以降を走査し、`app_name` の記載がある行ごとに `terraform/4_projects/<app_name>` ディレクトリを生成します。
1. `example_project` から Terraformの構成ファイルがコピーされ、Excelの値が注入された `terraform.tfvars` が配置されます。
