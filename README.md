# リポジトリ全体の目的と運用ルール

## Terraformファイルの基本的な使い方

1. `git clone`でリポジトリをダウンロード

    ```bash
    git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
    ```

1. domain.envに`my-domain.com`といった形式でダブルクオーテーションなどで囲わずにドメインを記入
1. **重要**: terraformコマンドを簡単にするためにgitリポジトリのルートディレクトリをaliasに追加しておく

    ```bash
    alias git-root='echo "$(git rev-parse --show-toplevel)"'
    ```

1. gcp-foundations/terraform/scriptsディレクトリで以下のコマンドを実行

   ```bash
   chmod +x *.sh
   ```

1. 一時的にgitのrootディレクトリのパスを通す

   `export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"`

1. `bash generate-backend-config.sh`を実行
1. `bash sync-domain-to-tfvars.sh`を実行
1. `bash setup-project-context.sh`を実行
1. docs/first_env_setup.mdを参考にtfstateファイル管理専用のプロジェクトを作成
1. terraform/1_core/base/logsinkディレクトリへ移動してログ集約シンクプロジェクトを作成
   1. terraform.tfvarsのラベルに値を入力

   ```bash
   # terraform.tfvarsイメージ
   project_name = "logsink"

   labels = {
      env         = ""
      app         = ""
      team        = ""
      partner     = "vendor-e-agency"
      cost-center = ""
      managed-by  = "terraform"
   }
   ```

1. terraform/1_core/services/logsink/google_project_serviceディレクトリへ移動してAPI有効化の設定
1. terraform/1_core/services/logsink/sinksディレクトリへ移動してログ集約シンクの設定
   1. 要件定義で作成した[ログ集約シンク設定ファイル](https://docs.google.com/spreadsheets/d/1pp-qeE457PHePtdSsADMWXy9yWtNI2fAnk_wa0KVmVE/edit?gid=0#gid=0 "Google Driveへリンク")からGASでcsv出力したgcp_log_sink_config.csvを同ディレクトリへコピー
   1. generate_terraform.pyを実行
      1. destinations.tf, iam.tf, sinks.tfの３ファイルが生成される
   1. `bash get-bucket-name.sh`を実行
   1. regionの指定があればterraform.tfvarsにregion=""の形式で追記

   ```bash
   # terraform.tfvarsイメージ
   project_apis = [
      "storage.googleapis.com",
      "iam.googleapis.com",
      "serviceusage.googleapis.com",         # API有効化用（google_project_service）
      "cloudresourcemanager.googleapis.com", # プロジェクト作成/管理
      "logging.googleapis.com",              # Stackdriver Logging / sinks
      "bigquery.googleapis.com",             # BigQuery（ログシンクを BigQuery にする場合）
   ]

   gcs_backend_bucket="tfstate-my-domain-tf-admin"
   ```

2. terraform/1_core/base/monitoringディレクトリへ移動してモニタリング専用のプロジェクトを作成

## リポジトリ構成

```plaintext
gcp-foundations/
├── .github/
│   └── workflows/
│       ├── org-apply.yml         # 組織レベルのCI/CDパイプライン
│       ├── folders-apply.yml     # フォルダ作成のCI/CDパイプライン
│       └── projects-apply.yml    # プロジェクト作成のCI/CDパイプライン
├── .gitignore
├── README.md                     # リポジトリ全体の目的と運用ルール
├── docs/
│   └── architecture.md           # 設計思想やアーキテクチャ図
│   ├── best_practice.md
│   ├── create_folder.md
│   ├── create_project.md
│   └── first_env_setup.md
├── policies/
│   ├── example_rego.md
│   └── require_labels.rego       # ポリシー・アズ・コードの定義
├── generate-backend-config.sh
└── terraform/                    # Terraformコードのルートディレクトリ
    ├── scripts/
    │   ├── get-billing-account-id.sh
    │   ├── get-organization-name.sh
    │   └── get-organization-id.sh
    ├── 0_bootstrap/              # 【責務⓪】Terraform基盤の初期構築
    │   ├── backend.tf            # 
    │   ├── provider.tf           # Google Cloudをプロバイダに指定️
    │   ├── versions.tf           # バージョンを固定
    │   ├── main.tf               # 管理用プロジェクトとGCSバケットを作成
    │   └── variables.tf
    │
    ├── 1_core/
    │   ├── base/
    │   │   ├── monitoring/
    │   │   │   ├── backend.tf
    │   │   │   ├── main.tf
    │   │   │   ├── provider.tf
    │   │   │   ├── variables.tf
    │   │   │   └── versions.tf
    │   │   └── logsink/
    │   │       ├── backend.tf
    │   │       ├── main.tf
    │   │       ├── outputs.tf
    │   │       ├── provider.tf
    │   │       ├── variables.tf
    │   │       └── versions.tf
    │   └── services/             # 【責務】作成済みプロジェクトへのリソース設定
    │       └── logsink/
    │           ├── docs/         # generate_terraform.pyのSphinx生成コード
    │           ├── backend.tf
    │           ├── generate_terraform.py
    │           ├── get-bucket-name.sh
    │           ├── provider.tf
    │           ├── variables.tf
    │           └── versions.tf
    │
    ├── 2_organization/           # 【責務①】組織全体の設定
    │   ├── backend.tf
    │   ├── main.tf               # 組織ポリシー、組織レベルのIAMなどを定義
    │   ├── versions.tf           # バージョンを固定
    │   └── variables.tf
    │
    ├── 3_folders/                # 【責務②】基本となるフォルダ構造
    │   ├── backend.tf
    │   ├── main.tf               # 'development', 'staging', 'production'などのフォルダを定義
    │   ├── versions.tf           # バージョンを固定
    │   └── variables.tf
    │
    └── 4_projects/               # 【責務③】プロジェクトの作成（Project Factory）
        └── example_project/      # アプリケーション'my_app'用のプロジェクト群
            ├── backend.tf
            ├── main.tf           # プロジェクト作成モジュールを呼び出す
            ├── versions.tf       # バージョンを固定
            ├── variables.tf
            ├── dev.tfvars        # 開発環境用プロジェクトの設定値
            ├── stag.tfvars       # ステージング環境用プロジェクトの設定値
            └── prod.tfvars       # 本番環境用プロジェクトの設定値
```
