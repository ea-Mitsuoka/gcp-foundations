# 貢献ガイドライン (Contributing Guidelines)

GCP Foundations への貢献にご関心をお寄せいただきありがとうございます。

本リポジトリは、高品質でセキュアなGCP基盤を提供するためのテンプレートおよびIaCコードの集合体です。すべての貢献者が円滑に開発を進められるよう、以下のガイドラインを遵守してください。

## バグ報告や機能要望 (Issues)

バグの報告や機能の要望は、GitHubのIssue機能を利用して受け付けています。
Issueを作成する際は、以下の点に注意してください。

- **バグの場合:** 再現手順、期待される動作、実際の動作、および関連するエラーログ（機密情報をマスキングしたもの）を明確に記載してください。
- **機能要望の場合:** その機能がなぜ必要なのか（ユースケース）、そしてどのような実装が望ましいと考えているかを詳細に記述してください。

## 開発フローとプルリクエスト (Pull Requests)

### 1. 開発環境の準備

ローカル開発環境のセットアップについては、[ローカル開発環境セットアップガイド](docs/development/local_development.md) を参照してください。

### 2. ブランチの作成

作業を開始する前に、`main` ブランチから新しいフィーチャーブランチを作成してください。
ブランチ名は作業内容が推測できる名前にしてください。

```bash
git checkout -b feature/add-new-logging-module
# または
git checkout -b fix/correct-iam-permissions
```

### 3. コミットメッセージの規則

本リポジトリでは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に従ったコミットメッセージを推奨しています。

例:

- `feat: add new terraform module for Cloud SQL`
- `fix(policy): resolve rego syntax error`
- `docs: update setup documentation`

### 4. コード規約と静的解析 (Lint)

すべての変更は、以下のツールによるチェックをパスする必要があります。これらはGitHub ActionsのCIパイプラインでも自動的に検証されます。

- **Terraform フォーマット:** `terraform fmt -recursive` による自動成形を適用すること。
- **TFLint:** `tflint --recursive` による静的解析でエラーが出ないこと。
- **OPA:** `.rego` ポリシーファイルの変更は `opa check` で検証されていること。

### 5. プルリクエスト（PR）の作成とレビュー

変更が完了したら、GitHub上でプルリクエストを作成します。

- PRのタイトルと説明には、変更の目的と内容を明確に記載してください。
- 関連するIssueがある場合は、PRの説明文に `Fixes #<Issue番号>` や `Resolves #<Issue番号>` と記載してリンクさせてください。
- レビュアーからのフィードバックには真摯に対応し、必要に応じてコードを修正してください。

## 行動規範 (Code of Conduct)

すべての参加者が快適に協力できるよう、多様性を尊重し、嫌がらせや差別的な言動を禁止します。技術的な議論は歓迎しますが、個人への攻撃は容認されません。
