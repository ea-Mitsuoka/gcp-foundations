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
- **期待結果**: `.git` が再初期化され、機密情報を含む可能性のある過去の履歴が消去されること。

______________________________________________________________________

## 3. SSoT定義と自動生成の網羅的検証 (TC-SSOT)

### TC-SSOT-01: `log_sinks` シートの反映
- **手順**:
  1. `gcp-foundations.xlsx` の `log_sinks` シートを編集。
  1. `make generate` を実行。
- **期待結果**:
  - `terraform/1_core/services/logsink/sinks/gcp_log_sink_config.csv` が正しく生成・更新されていること。
  - `make test`（自動テスト）または `make deploy` の事前 `plan` により、設定の整合性が確認されること。

### TC-SSOT-02: タグ定義とバインディング
- **手順**:
  1. `tag_definitions` と `resources` シートの `org_tags` を編集。
  1. `make generate` を実行。
- **期待結果**: `auto_tags.tf` および各プロジェクトのコードにタグ定義とバインディングが出力されること。

______________________________________________________________________

## 4. プロジェクト・ライフサイクルの検証 (TC-LC)

### TC-LC-01: プロジェクトの追加フロー
- **手順**: Excel追記 -> `make generate` -> `make deploy` を実行。
- **期待結果**: GCP上でプロジェクトが作成され、正しいラベルが付与されていること。

### TC-LC-02: 削除保護 (Deletion Protection) の挙動
- **手順**:
  1. `deletion_protection = true` で `make deploy`。
  1. `make destroy` を実行（グローバルまたは特定レイヤー）。
  1. `false` に変更して `make deploy` 後、再度 `make destroy`。
- **期待結果**: 2では削除が拒否され、3では正常に削除が完了すること。

### TC-LC-03: 課金リンク待ち状態の再開フロー
- **手順**: `core_billing_linked` を `false` で `make deploy` -> 課金リンク実施 -> `true` で `make deploy`。
- **期待結果**: 後続の API 有効化ステップが正常に再開されること。

______________________________________________________________________

## 5. ガバナンスと自動テストの検証 (TC-GOV)

### TC-GOV-01: OPA (Rego) によるガバナンスチェック
- **手順**:
  1. 必須ラベル（env, owner）を欠いた状態にする。
  1. `make opa` または `make test` を実行。
- **期待結果**: ポリシー違反が検知され、ビルドまたはテストが失敗すること。

### TC-GOV-02: モジュールおよびスクリプトの品質
- **手順**: `make lint` および `make test` を実行。
- **期待結果**: Terraform の構文チェック、TFLint、Python のユニットテストがすべてパスすること。
