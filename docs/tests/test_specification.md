# GCP Foundations テスト仕様書

## 1. はじめに

### 1.1. 目的

本ドキュメントは、[テスト計画書](./test_plan.md)および[テスト設計書](./test_design.md)に基づき、`gcp-foundations`リポジトリの全機能および運用プロセスが仕様通りに動作することを確認するための詳細なテストケースを定義する。
本仕様書は `Makefile` で提供される抽象化コマンドを前提とし、生の `terraform` コマンドを直接使用せずに運用プロセスを検証する。

______________________________________________________________________

## 2. 運用コマンドと初期構築の検証 (TC-OPS)

### TC-OPS-01: `make setup` によるシードリソース作成

- **手順**:
  1. クリーンなGCP組織で `make setup` を実行。
  1. 対話プロンプトに従い、プロジェクト名や課金IDを入力。
- **期待結果**:
  - 管理プロジェクト、tfstate用GCSバケット、Terraform実行用SAが作成される。
  - `terraform/common.tfvars` と `terraform/common.tfbackend` が自動生成される。

### TC-OPS-02: `make check` (Pre-flight Check) の精度

- **手順**:
  1. 必要な権限を持っていないアカウントで `make check` を実行。
  1. 正しい権限を持つアカウントに切り替えて再度実行。
- **期待結果**: 1では権限不足のエラーを報告し、2では全項目がパスすること。

### TC-OPS-03: `make delivery` (納品準備)

- **手順**: `make delivery` を実行。
- **期待結果**:
  - `.git` が再初期化され、機密情報を含む可能性のある過去の履歴が消去されること。
  - 実行後は `git log` が初期状態（1コミット）になっていること。

### TC-OPS-04: `make clean` による環境クリーンアップ

- **手順**:
  1. `make clean` を実行。
  1. その後 `make generate` および各レイヤーでの `terraform init` を実行。
- **期待結果**: ローカルキャッシュ（.terraform等）が正常に削除され、再初期化後に依存関係が正しく復元されること。

______________________________________________________________________

## 3. SSoT定義と自動生成の網羅的検証 (TC-SSOT)

### TC-SSOT-01: `log_sinks` シートの反映

- **手順**:
  1. `gcp-foundations.xlsx` の `log_sinks` シートを編集。
  1. `make generate` を実行。
- **期待結果**:
  - `terraform/1_core/services/logsink/sinks/gcp_log_sink_config.csv` が正しく生成・更新されていること。
  - `make test` または `make deploy` (plan) により、設定の整合性が確認されること。

### TC-SSOT-02: タグ定義とバインディング

- **手順**:
  1. `tag_definitions` と `resources` シートの `org_tags` を編集。
  1. `make generate` を実行。
- **期待結果**: `auto_tags.tf` および各プロジェクトのコードにタグ定義とバインディングが出力されること。

### TC-SSOT-03: `shared_vpc_subnets` の重複・衝突チェック

- **手順**:
  1. Excel で既存のサブネットと同一の名前、または重複する IP 範囲を定義。
  1. `make generate` を実行し、バリデーション結果を確認。
- **期待結果**: Python スクリプトによるバリデーション（`ResourceValidator`）で重複を検知し、エラーで停止すること。

### TC-SSOT-04: `notifications` および `vpc_sc` の連携確認

- **手順**:
  1. Excel の該当シートを編集し `make generate` を実行。
- **期待結果**:
  - `notifications.csv` 等が Monitoring/Alert 等の各モジュールディレクトリへ正しく配備されていること。
  - VPC-SC 境界の定義が `auto_vpc_sc.tf` に正しく出力され、意図しないアクセス拒否設定が含まれていないこと。

______________________________________________________________________

## 4. プロジェクト・ライフサイクルの検証 (TC-LC)

### TC-LC-01: プロジェクトの追加フロー

- **手順**: Excel追記 -> `make generate` -> `make deploy` を実行。
- **期待結果**: GCP上でプロジェクトが作成され、正しいラベル（env, owner, app）が付与されていること。

### TC-LC-02: 削除保護 (Deletion Protection) の挙動

- **手順**:
  1. `deletion_protection = true` で `make deploy`。
  1. `make destroy` を実行（グローバルまたは特定レイヤー）。
  1. `false` に変更して `make deploy` 後、再度 `make destroy`。
- **期待結果**: 2では削除が拒否され、3では正常に削除が完了すること。

### TC-LC-03: 課金リンク待ち状態の再開フロー

- **手順**: `core_billing_linked = false` で `make deploy` -> 課金リンク実施 -> `true` で `make deploy`。
- **期待結果**: 初回実行時は API 有効化がスキップされ、再開後は全サービスが正常にデプロイされること。

### TC-LC-04: 名前変更・削除による破壊的変更の検知

- **手順**:
  1. Excel 上で既存のリソース名（フォルダ・プロジェクト）を変更、または行を削除。
  1. `make generate` -> `make deploy` (plan) を実行。
- **期待結果**: Terraform Plan において「Destroy and Create replacement」または「Delete」として検知され、データ消失リスクを事前に識別できること。

______________________________________________________________________

## 5. ガバナンスと自動テストの検証 (TC-GOV)

### TC-GOV-01: OPA (Rego) によるガバナンスチェック

- **手順**:
  1. 必須ラベル（env, owner）を欠いたプロジェクトを定義する。
  1. `make opa` または `make test` を実行。
- **期待結果**: ポリシー違反が検知され、ビルドまたはテストが失敗すること。

### TC-GOV-02: モジュールおよびスクリプトの品質 (Lint/UnitTest)

- **手順**: `make lint` および `make test` を実行。
- **期待結果**:
  - TFLint、ShellCheck、Terraform 構文チェックがパスすること。
  - `test_generate_resources.py` による Python ユニットテストがすべてパスすること。
