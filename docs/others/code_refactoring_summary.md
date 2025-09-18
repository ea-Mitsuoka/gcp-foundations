# コードの変更点サマリー

今回の変更は、Terraformの構成をより宣言的で再利用しやすくするための大規模なリファクタリングです。主な変更点は以下の通りです。

## 1. **Pythonスクリプトの廃止とTerraformネイティブ化 (最重要)**

- `1_core/services/logsink/sinks` ディレクトリにあったPythonスクリプト (`generate_terraform.py`) を完全に**廃止**しました。
- 代わりに、Terraformの `csvdecode` 関数と `for_each` を活用し、`gcp_log_sink_config.csv` からログシンク、宛先リソース (BigQuery/GCS)、IAM権限を**動的に直接生成**するように変更しました。
- これにより、Terraformの実行前にPythonスクリプトを実行する必要がなくなり、`terraform apply` だけで完結するようになりました。
- Pythonコードのロジック（宛先の重複排除、GCSの動的な保存期間設定、リソース名の命名規則など）は、`locals.tf` 内で忠実に再現されています。

## 2. **Provider設定の一元化**

- これまで各サブディレクトリに散らばっていた `provider.tf` ファイルを削除し、`0_bootstrap`、`1_core`、`3_folders` などの**各ステージのルートに一元化**しました。
- これにより、サービスアカウントの借用（impersonate）やデフォルトリージョンの設定が、各ステージ単位でまとめて管理されるようになり、コードの重複が大幅に削減されました。

## 3. **外部スクリプト依存の排除**

- プロジェクト作成時などに組織情報を取得するために使用していたシェルスクリプト (`get-organization-name.sh` など) と `data "external"` ブロックを**廃止**しました。
- 代わりに、Terraformネイティブの `data "google_organization"` を使用するように変更。`common.tfvars` からドメイン名を読み込み、API経由で組織情報を安全かつ宣言的に取得するようになりました。

## 4. **モジュール構成の改善**

- 汎用的なモジュール (`project-services`, `project-iam`) が新設され、各所で利用されるようになりました。
- プロジェクト作成用の `gcp-project` モジュールは、より責務が明確な `project-factory` モジュールに置き換えられました。

## 5. **セットアップスクリプトの改善**

- バックエンド設定ファイル (`common.tfbackend`) を生成するスクリプトをリポジトリルートから`terraform/scripts`配下に移動し、より堅牢なものに改良しました。
- 新たに `sync-domain-to-tfvars.sh` スクリリプトを追加し、`domain.env` から `common.tfvars` へドメイン名を自動で同期する仕組みを導入しました。

## 6. **構文エラーの修正**

- `iam.tf` 内でTerraformの構文エラーとなっていた `contains` 演算子を、正しい文字列部分一致関数 `strcontains()` に修正しました。
