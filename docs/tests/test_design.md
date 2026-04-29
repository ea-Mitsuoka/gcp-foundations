# GCP Foundations テスト設計書

## 1. はじめに

### 1.1. 目的

本ドキュメントは、[テスト計画書](./test_plan.md)に基づき、`gcp-foundations`リポジトリのテストを実施するための具体的なアプローチ、テストデータの設計、および自動化の仕組みを定義する。

______________________________________________________________________

## 2. 自動化テストの設計 (Automation Design)

### 2.1. Python ロジックの結合テスト

`ResourceValidator` 単体ではなく、`generate_resources.py` がExcelを読み込んで正しいTerraformファイルを生成するまでを検証する。

- **検証ツール**: `pytest`
- **設計**:
  - 正常系/異常系のExcelファイルを `tests/fixtures/` に用意。
  - スクリプトを実行し、終了コードを検証。
  - 生成された `auto_folders.tf` 等のファイルが、期待される文字列（正規表現でチェック）を含んでいるか、またはファイルが存在しないことを確認。

### 2.2. Terraform モジュールテスト

`terraform/modules/` 配下の部品が、単体でGCPの仕様を満たす構成を生成するかを検証する。

- **検証ツール**: `terraform test` (Terraform 1.6+)
- **設計**:
  - 各 `.tftest.hcl` において、`plan` 実行後の `root_module` の出力を検証。
  - 例：`project-factory` モジュールで `billing_account` が `lifecycle` で無視されている設定が、実行プランに正しく反映されているかを確認。

### 2.3. OPA ポリシーテスト

Regoファイル自体のロジックが正しいかを検証する。

- **検証ツール**: `opa test`
- **設計**:
  - `policies/` 配下に `*_test.rego` を作成。
  - モックされた `input`（Terraform plan JSON）を流し込み、期待通り `deny` が発生するかをテスト。

______________________________________________________________________

## 3. テストデータ設計 (Test Data Design)

テストシナリオを再現するためのExcelフィクスチャを以下のカテゴリで整備する。

| カテゴリ | ファイル名 | 検証の目的 |
| :--- | :--- | :--- |
| **Happy Path** | `fixture_standard.xlsx` | 標準的なフォルダ・プロジェクト・VPC・VSCの全自動生成。 |
| **Hierarchy** | `fixture_circular.xlsx` | 循環参照エラーの検知。 |
| **Network** | `fixture_overlap_cidr.xlsx` | サブネットIP重複エラーの検知。 |
| **Security** | `fixture_vsc_missing.xlsx` | 定義されていないVPC-SC境界を参照した際のエラー検知。 |
| **Migration** | `fixture_no_org_policy.xlsx` | 組織ポリシー無効化設定時の生成コード検証。 |

______________________________________________________________________

## 4. 異常系・限界系のテスト設計

| シナリオ | 設計内容 | 期待結果 |
| :--- | :--- | :--- |
| **Quota不足** | プロジェクト作成クォータを1に設定したテスト組織で、2つのプロジェクトをデプロイ。 | 1つ目は成功、2つ目はAPIエラーで停止し、`deploy_all.sh` がそこで中断されること。 |
| **API依存** | `compute.googleapis.com` を無効化した状態で、VMを含むレイヤーを適用。 | TerraformがAPI未有効化を検知し、適切な有効化案内エラーを出すこと。 |
| **権限不足** | `roles/viewer` のみのユーザーで `make setup` を実行。 | プロジェクト作成権限不足で、リソース作成前にエラー停止すること。 |

______________________________________________________________________

## 5. 継続的インテグレーション (CI) ワークフロー

GitHub Actions における検証パイプラインを以下の順序で構成する。

1. **Lint Phase**: `ruff`, `terraform fmt`, `tflint`.
1. **Unit Test Phase**: `pytest` (Python), `terraform test` (Modules), `opa test` (Rego).
1. **Integration Phase**:
   - `make generate` を各フィクスチャに対して実行。
   - 生成されたコードに対して `terraform validate` を実行し、構文の正しさを保証。
1. **Security Phase**: `checkov` を生成後の全ディレクトリに対して実行。
