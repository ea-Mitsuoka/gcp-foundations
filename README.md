# GCP Foundations (Terraform IaC)

このリポジトリは、Terraformを使用してGoogle Cloud Platform (GCP) 環境を体系的に構築・管理するための Infrastructure as Code (IaC) 基盤です。ガバナンスを確保しつつ、セキュアで再利用可能なGCP環境を効率的に展開することを目的とします。初心者でも迷わず、再現性高くセキュアなGCP環境を展開できるように設計されています。

## 🌟 主な特長

- **階層構造の自動生成**: Excel (SSoT) に定義するだけで、GCP 組織直下のフォルダ構造やプロジェクトを自動作成。
- **ネットワークとセキュリティの統合管理**: Shared VPC のサブネット、VPC Service Controls (VPC-SC) の境界・アクセスレベルを Excel 上で一元管理。
- **段階的な組織ポリシーの適用**: 移行プロジェクトに配慮し、初期状態では組織ポリシーを無効化した状態で作成可能。準備が整い次第、Excel の定義に基づき段階的にガードレールを適用できます。
- **責務の分離による迅速な払い出し**: アプリ用プロジェクトの API 有効化を現場に委譲。基盤チームはネットワーク（Shared VPC）やセキュリティ境界（VPC-SC）といった「セキュアな箱」の提供に集中できます。
- **Terraform による透過的な管理**: 全ての設定は Terraform コードへ変換され、ステート管理されるため、IaC としての整合性を維持。

## 🚀 5分でわかるクイックスタート

まずはローカル環境で自動生成と品質チェックの流れを体験してみましょう。

```bash
# 1. リポジトリのクローン
git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
cd gcp-foundations

# 2. 必要なツールのインストール (uv環境の同期)
make install

# 3. Excel設計図からTerraform構成を出力 (初回はテンプレート作成)
make generate

# 4. 生成されたコードの品質チェック
make lint
```

### 🛠️ 実際の構築を始める場合

実際のGCP環境へのデプロイは、以下の3ステップで行います。

1. **`make setup`**: GCP組織に管理プロジェクトやtfstate保存用バケットを作成。
1. **Excelの編集**: `gcp-foundations.xlsx` にフォルダやプロジェクトを定義。
1. **`make deploy`**: 依存関係を考慮して全レイヤーを自動デプロイ。

詳細は **[環境構築の全体手順 (セッション用)](docs/setup/initial_setup.md)** を参照してください。

## 📚 ドキュメントインデックス (ここから読み始めてください)

本リポジトリの設計や運用に関するあらゆる情報は、以下のドキュメントに集約されています。目的別にカテゴリ分けされています。

### 📌 初期構築・セットアップ (Setup)

一番最初に実行する環境構築手順や、開発者としての参加手順です。

1. **[環境構築の全体手順 (セッション用)](docs/setup/initial_setup.md)**: 基盤のゼロからの構築・デプロイ手順
1. **[Google グループ作成ガイド](docs/setup/google_groups_creation.md)**: Cloud セットアップを活用した効率的なグループ作成
1. **[スプレッドシート・ワークショップ・ガイド](docs/operations/spreadsheet_session_guide.md)**: 顧客と一緒に設計図を完成させるためのガイド
1. **[複数環境の管理と方針](docs/setup/setup_environment.md)**: Workspaceを利用しないSSoTベースの管理思想
1. **[ローカル開発環境セットアップガイド](docs/development/local_development.md)**: 開発者向けの必須ツールのインストールと設定

### ⚙️ 日常運用手順 (Operations)

日々のリソース作成や更新、引き渡しを行う際のマニュアルです。

1. **[プロジェクトのライフサイクル管理](docs/operations/project_lifecycle.md)**: スプレッドシート（SSoT）に基づく作成・運用・管理
1. **[トラブルシューティング・ガイド](docs/operations/troubleshooting.md)**: 構築・運用中によくある問題と解決策
1. **[ネットワークとセキュリティの詳細設定](docs/setup/spreadsheet_format.md)**: Shared VPC, VPC-SC, 組織ポリシーの管理方法
1. **[環境の一括解体・クリーンアップガイド](docs/operations/environment_destruction.md)**: make destroy の仕様とオプション解説
1. **[フォルダの作成手順](docs/operations/folder_creation.md)**: Terraformによるフォルダ階層の管理
1. **[共通モジュールのメンテナンス](docs/operations/module_maintenance.md)**: モジュール改修時のデプロイ戦略
1. **[後任者・リカバリガイド](docs/operations/recovery_and_succession.md)**: 設定ファイルの復元と安全な引き継ぎ
1. **[顧客引き渡し手順](docs/operations/handover_procedure.md)**: 納品時に実行するGit履歴のクリアと権限移譲の手順

### 📖 リファレンス・設計資料 (Reference & Architecture)

本基盤の設計思想や、詳細な仕様です。

1. **[アーキテクチャ設計書](docs/design/architecture.md)**: 全体俯瞰図とSSoT・レイヤー構造の解説
1. **[ベストプラクティス集](docs/reference/best_practices.md)**: インフラ運用とIAM・権限管理の方針
1. **[スプレッドシートの仕様書](docs/setup/spreadsheet_format.md)**: `gcp-foundations.xlsx` (SSoT) のカラム定義
1. **[データディクショナリ](docs/design/data-dictionary.md)**: Terraform変数の定義や命名規則
1. **[ガバナンス・エボリューション・ガイド](docs/reference/governance_guideline.md)**: 運用継続のポイントと責務の境界線についての指針

### 🛠️ 便利な Makefile コマンド

日々の運用や開発において、パスや長大なコマンドを覚える必要はありません。リポジトリルートで `make` を使用してください。

```bash
make help       # 利用可能な全コマンドの表示
make setup      # 初期構築（管理用プロジェクト・tfstateバケットの作成）
make generate   # Excel(SSoT)からTerraform変数や構成を自動生成
make lint       # Terraform, ShellscriptのLint・フォーマット実行
make opa        # Regoポリシーの構文チェック
make test       # モジュールの単体テスト実行
make deploy     # 基盤全体の一括デプロイ実行
make delivery   # 納品用リポジトリの作成 (Git履歴リセット)
```

## 📖 設計思想

この基盤は、責務の分離と段階的なインフラ構築を重視した**レイヤー構造**を採用しています。各レイヤーは独立したTerraformのルートモジュールとして管理され、下位のレイヤーに依存します。

```mermaid
graph TD
    A[0. Bootstrap] --> B[1. Core Services];
    B --> C[2. Organization];
    C --> D[3. Folders];
    D --> E[4. Projects];
```

- **Layer 0: Bootstrap**
  - Terraformの実行基盤自体を構築します。
  - 責務: `tfstate`を管理するGCSバケットの作成。
- **Layer 1: Core Services**
  - 組織全体で共有される中核サービス（ログ集約、モニタリングなど）を構築します。このレイヤーは、**`base`** と **`services`** という2つのサブディレクトリに分かれており、責務が明確に分離されているのが特徴です。
    - `1_core/base/`: 共有プロジェクトという「器」そのものを作成する責務を担います。（例: `logsink`プロジェクト）
    - `1_core/services/`: `base`で作成した「器」の中に、API有効化やログシンク設定といった具体的な「中身（サービス）」を実装する責務を担います。
  - この「器」と「中身」を分離する設計により、インフラの構成がシンプルで見通しが良くなり、将来的な機能追加も容易になっています。
  - 責務: 共有プロジェクトの作成と、そのプロジェクト内へのサービス実装。
- **Layer 2: Organization**
  - 組織全体に適用されるポリシーやIAM設定を管理します。
  - 責務: 組織ポリシー、組織レベルでのIAM設定。
- **Layer 3: Folders**
  - `production`, `staging`, `development` といった、リソースを階層的に管理するためのフォルダ構造を定義します。
  - 責務: 基本となるフォルダの作成とIAM設定。
- **Layer 4: Projects**
  - "Project Factory" パターンに基づき、各アプリケーションやチームのためのGCPプロジェクトを作成します。
  - 責務: アプリケーションごとのプロジェクトの作成、API有効化、サービスアカウント設定など。

## 🚀 ワンストップ・デプロイ

すべてのリソースのデプロイは、以下のスクリプトを1回叩くだけで完了します。

```bash
make deploy
```

※ 事前に `gcp-foundations.xlsx` と `domain.env` を更新し、Single Source of Truth (SSoT) を最新化してください。

______________________________________________________________________

## 🚀 新規顧客向け 環境構築手順

このリポジトリをテンプレートとして使い、新しい顧客のGCP組織にインフラ基盤を払い出すためのセットアップは、自動化スクリプトを実行するだけで簡単に行えます。

### 前提条件

- `gcloud` CLI, `terraform` CLI, `git`, `openssl`, `uv` がローカル環境にインストールされていること。

- **Google Groups の事前作成 (必須):** ([Googleグループ作成ガイド](docs/setup/google_groups_creation.md) 参照)
  Google Workspace (または Cloud Identity) 上で、後述の組織IAMに必要な以下のグループ（メーリングリスト）を事前に作成しておいてください。

  - `gcp-organization-admins@<顧客ドメイン>`
  - `gcp-billing-admins@<顧客ドメイン>`
  - `gcp-vpc-network-admins@<顧客ドメイン>`
  - `gcp-hybrid-connectivity-admins@<顧客ドメイン>`
  - `gcp-logging-monitoring-admins@<顧客ドメイン>`
  - `gcp-logging-monitoring-viewers@<顧客ドメイン>`
  - `gcp-security-admins@<顧客ドメイン>`
  - `gcp-developers@<顧客ドメイン>`
  - `gcp-devops@<顧客ドメイン>`

- 顧客のGCP組織に対する**組織管理者**などの強い権限を持つアカウントで、`gcloud`にログイン済みであること。

  ```bash
  gcloud auth login
  gcloud auth application-default login
  ```

### 手順

1. **リポジトリをクローンし、ディレクトリに移動します。**

   ```bash
   git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
   cd gcp-foundations
   ```

1. **初期構築コマンドを実行します。**

   ```bash
   make install  # 依存関係のインストール
   make setup    # シードリソース（管理プロジェクト・バケット）の作成
   ```

   `make setup` スクリプトが対話形式で必要な情報を質問し、tfstate管理基盤の構築を自動で行います。

1. **手動で課金アカウントをリンクします。**

   スクリプトの最後に表示される `gcloud billing projects link ...` コマンドを、指示に従って実行してください。
   ※ 権限の仕様上、このステップのみ手動での実行が必須となっています。

1. **`0_bootstrap` を適用し、Terraform管理を開始します。**

   ```bash
   cd terraform/0_bootstrap
   terraform init -backend-config="../common.tfbackend"
   terraform apply -var-file="../common.tfvars"
   ```

これ以降の各レイヤーの展開については、**[環境構築の全体手順 (セッション用)](docs/setup/initial_setup.md)** を参照してください。

## 🤝 コントリビューションとセキュリティ

本プロジェクトへの貢献方法やバグ報告のルールについては、以下のドキュメントを必ずご確認ください。

- **[貢献ガイドライン (CONTRIBUTING.md)](CONTRIBUTING.md)**: PRの作成手順やコーディング規約、行動規範について。
- **[セキュリティポリシー (SECURITY.md)](SECURITY.md)**: 脆弱性の報告方法やシークレット管理の原則について。

## CI/CDによる自動化

このリポジトリでは、GitHub Actionsを用いたCI/CDパイプラインが `.github/workflows/` に定義されています。

- **PR時の自動チェック**: プルリクエスト作成時に `terraform plan` と `OPA (Rego)` によるセキュリティ/構成チェックが自動実行されます。
- **Drift検知**: 毎週日曜日に全環境の `terraform plan` を実行し、コードと実環境の乖離（ドリフト）を自動検知して通知します。

______________________________________________________________________

## 📂 リポジトリ構成

```plaintext
gcp-foundations/
├── .github/
│   └── workflows/          # CI/CDワークフロー (PR時の自動チェック、Drift検知等)
├── docs/                   # マニュアル・設計資料 (トラブルシューティング等は operations/ を参照)
├── policies/               # セキュリティ統制ルール (Rego/OPA)
├── scripts/                # 運用補助スクリプト
└── terraform/              # インフラ定義の本体
    ├── 0_bootstrap/        # L0: 基盤の「鍵」となるtfstate管理用の器
    ├── 1_core/             # L1: ログ集約・監視・共通NWなどの「心臓部」
    ├── 2_organization/     # L2: 組織全体に強制するセキュリティポリシー
    ├── 3_folders/          # L3: 組織図を反映するフォルダ階層 (自動生成)
    ├── 4_projects/         # L4: 各アプリが動くプロジェクト (自動生成)
    ├── modules/            # 再利用可能な部品 (プロジェクト、API有効化等)
    └── configs/            # グローバルな共通変数
```
