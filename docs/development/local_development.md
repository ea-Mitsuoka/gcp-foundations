# ローカル開発環境セットアップガイド

本プロジェクト（GCP Foundations）の開発に参加するエンジニア向けの、ローカル環境のセットアップガイドです。

## 1. 必須ツールのインストール

本リポジトリの開発・運用にあたり、以下のツールが必須となります。事前にインストールしてください。

### Terraform (1.6.0 以上)

インフラストラクチャをコードとして管理・デプロイするためのメインツールです。

- [公式インストールガイド](https://developer.hashicorp.com/terraform/install)
- `tfenv` や `asdf`, `mise` などのバージョン管理ツールを使用してプロジェクトごとにバージョンを合わせることを推奨します。

### Google Cloud CLI (gcloud)

GCPリソースへの認証と操作を行うためのCLIツールです。

- [公式インストールガイド](https://cloud.google.com/sdk/docs/install)

### uv (Python パッケージマネージャ)

Terraformの変数ファイル（`tfvars`）やリソース定義を自動生成するPythonスクリプト（`generate_resources.py`）を実行するために使用します。高速で依存関係管理が不要な点が特徴です。

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### TFLint

Terraformコードの静的解析（Lint）を行い、エラーや非推奨な記述を検知します。

- [公式インストールガイド](https://github.com/terraform-linters/tflint)

```bash
# macOS (Homebrew)
brew install tflint

# Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

### Open Policy Agent (OPA)

`.rego` ファイルに記述されたポリシーアズコード（Policy as Code）の構文チェックとテストを実行します。

- [公式インストールガイド](https://www.openpolicyagent.org/docs/latest/#1-download-opa)

______________________________________________________________________

## 2. GCP 認証情報のセットアップ

開発を開始する前に、対象となるGCP組織に対する適切な権限（組織管理者など）を持つアカウントで認証を行う必要があります。

```bash
# gcloud CLIのログイン
gcloud auth login

# アプリケーションのデフォルト認証情報の取得 (Terraform用)
gcloud auth application-default login
```

______________________________________________________________________

## 3. リポジトリのクローンと初期設定

```bash
git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
cd gcp-foundations
```

### パスの設定

`terraform/scripts/` 配下にあるスクリプト群にどこからでもアクセスできるよう、シェルの設定ファイル（`.bashrc` または `.zshrc` など）に以下を追記することを推奨します。

```bash
export PATH="$(git rev-parse --show-toplevel 2>/dev/null)/terraform/scripts:$PATH"
```

______________________________________________________________________

## 4. 開発ワークフロー

コードの変更を行った後は、コミットする前に以下のコマンドを実行してコードの品質を担保してください。これらはGitHub Actions（CI）でもチェックされます。

### Terraformコードのフォーマット

```bash
cd terraform
terraform fmt -recursive
```

### TFLintによる静的解析

```bash
cd terraform
tflint --init
tflint --recursive
```

### Regoポリシーのチェック

```bash
opa check policies/*.rego
```

これらのチェックを通過したことを確認してから、プルリクエスト（PR）を作成してください。
