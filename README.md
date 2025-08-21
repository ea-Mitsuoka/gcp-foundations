# リポジトリ全体の目的と運用ルール

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
├── policies/
│   └── require_labels.rego       # ポリシー・アズ・コードの定義
└── terraform/                    # Terraformコードのルートディレクトリ
    ├── 0_bootstrap/              # 【責務⓪】Terraform基盤の初期構築
    │   ├── backend.tf            # 
    │   ├── provider.tf           # Google Cloudをプロバイダに指定️
    │   ├── versions.tf           # バージョンを固定
    │   ├── main.tf               # 管理用プロジェクトとGCSバケットを作成
    │   └── variables.tf
    │
    ├── 1_organization/           # 【責務①】組織全体の設定
    │   ├── backend.tf
    │   ├── main.tf               # 組織ポリシー、組織レベルのIAMなどを定義
    │   ├── versions.tf           # バージョンを固定
    │   └── variables.tf
    │
    ├── 2_folders/                # 【責務②】基本となるフォルダ構造
    │   ├── backend.tf
    │   ├── main.tf               # 'development', 'staging', 'production'などのフォルダを定義
    │   ├── versions.tf           # バージョンを固定
    │   └── variables.tf
    │
    └── 3_projects/               # 【責務③】プロジェクトの作成（Project Factory）
        └── example_project/      # アプリケーション'my_app'用のプロジェクト群
            ├── backend.tf
            ├── main.tf           # プロジェクト作成モジュールを呼び出す
            ├── versions.tf       # バージョンを固定
            ├── variables.tf
            ├── dev.tfvars        # 開発環境用プロジェクトの設定値
            ├── stag.tfvars       # ステージング環境用プロジェクトの設定値
            └── prod.tfvars       # 本番環境用プロジェクトの設定値
```
