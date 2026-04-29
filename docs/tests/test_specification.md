# GCP Foundations テスト仕様書

## 1. はじめに

### 1.1. 目的

本ドキュメントは、[テスト計画書](./test_plan.md)および[テスト設計書](./test_design.md)に基づき、`gcp-foundations`リポジトリの全機能および運用プロセスが仕様通りに動作することを確認するための詳細なテストケースを定義する。
本仕様書は、SSoT定義、自動生成、デプロイ、運用ライフサイクル、およびセキュリティガバナンスの全領域をカバーする。

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
  1. 必要な権限（組織管理者など）を持っていないアカウントで `make check` を実行。
  1. 正しい権限を持つアカウントに切り替えて再度実行。
- **期待結果**:
  - 1では権限不足のエラーを正しく報告すること。
  - 2では全項目が「OK」または「PASS」となること。

### TC-OPS-03: `make delivery` (納品準備)

- **手順**: 開発完了後のリポジトリで `make delivery` を実行。
- **期待結果**:
  - `.git` ディレクトリが再初期化され、過去のコミット履歴が消去されていること。
  - `docs/` や `terraform/` のファイル構成は維持されていること。

______________________________________________________________________

## 3. SSoT定義と自動生成の網羅的検証 (TC-SSOT)

### TC-SSOT-01: `log_sinks` シートの反映

- **手順**:
  1. `log_sinks` シートに BQ宛先（365日保持）と GCS宛先（90日保持）の2行を追加。
  1. `make generate` を実行。
- **期待結果**:
  - `terraform/1_core/services/logsink/sinks/locals.tf` の `sink_configs` に反映されていること。
  - 同ディレクトリのデプロイにより、組織レベルのログシンクが作成されること。

### TC-SSOT-02: `tag_definitions` と `org_tags`

- **手順**:
  1. `tag_definitions` に `cost_center` キーと値を定義。
  1. `resources` シートの特定プロジェクトに `cost_center/123` を付与。
  1. `make generate` 実行。
- **期待結果**:
  - `terraform/2_organization/auto_tags.tf` に `google_tags_tag_key` 等が出力されること。
  - プロジェクト側のコードに `google_tags_tag_binding` が出力されること。

### TC-SSOT-03: `shared_vpc_subnets` の重複・境界チェック

- **手順**:
  1. 同一の `subnet_name` を持つ2行を定義し `make generate`。
  1. 重複するIP範囲（10.0.0.0/24 と 10.0.0.128/25）を定義し `make generate`。
- **期待結果**: いずれもバリデーションエラーで停止すること。

______________________________________________________________________

## 4. プロジェクト・ライフサイクルの検証 (TC-LC)

### TC-LC-01: プロジェクトの追加フロー

- **手順**: `project_lifecycle.md` に従い、Excel追記 -> `make generate` -> `make deploy` を実行。
- **期待結果**:
  - 新規プロジェクトディレクトリが `terraform/4_projects/` に作成される。
  - デプロイ後、GCP上でプロジェクトが作成され、正しいラベル（env, owner, app）が付与されている。

### TC-LC-02: 削除保護 (Deletion Protection) の挙動

- **手順**:
  1. `terraform/4_projects/[name]/terraform.tfvars` の `deletion_protection` を `true` に設定してデプロイ。
  1. 同ディレクトリで `terraform destroy` (または `apply -destroy`) を試行。
  1. `deletion_protection = false` に変更して `apply` 後、再度削除を試行。
- **期待結果**:
  - 2では Terraform または GCP API によって削除が拒否されること。
  - 3では正常に削除が完了すること。

### TC-LC-03: 課金リンク待ち状態の再開フロー

- **手順**:
  1. `common.tfvars` で `core_billing_linked = false` に設定。
  1. `make deploy` を実行。
  1. プロジェクト作成完了後、手動で課金リンクを実施。
  1. `core_billing_linked = true` に書き換えて再度 `make deploy`。
- **期待結果**:
  - 初回実行時は API 有効化レイヤーがスキップされる。
  - 再実行時はスキップされていたレイヤー（services 配下）が正常に適用される。

______________________________________________________________________

## 5. セキュリティガバナンスの検証 (TC-SEC)

### TC-SEC-01: 組織ポリシーのグローバルスイッチ

- **手順**:
  1. `common.tfvars` の `enable_org_policies` を `false` にして `make deploy`。
  1. コンソールから SAキーを作成（成功するはず）。
  1. `true` に変更して `make deploy`。
  1. 再度 SAキーを作成。
- **期待結果**: 3のデプロイ後は SAキーの作成が拒否されること。

### TC-SEC-02: OPA (Rego) によるラベル必須化チェック

- **手順**:
  1. `terraform/4_projects/[name]/terraform.tfvars` から `labels` の `env` 行を削除。
  1. `terraform plan -out=tfplan` -> `terraform show -json tfplan > plan.json`。
  1. `opa eval --data policies/ --input plan.json "data.gcp.policies.deny"` を実行。
- **期待結果**: `missing_labels: {"env"}` を含むエラーメッセージが返されること。

______________________________________________________________________

## 6. E2E機能と運用の検証 (TC-E2E)

### TC-E2E-01: 中央監視プロジェクトの可視性

- **前提**: `central_monitoring = true` のプロジェクト A と `false` のプロジェクト B をデプロイ。
- **手順**: モニタリングプロジェクトのダッシュボードで、両プロジェクトのメトリクスが表示されるか確認。
- **期待結果**: A のデータは表示され、B のデータは表示されない（または権限エラー）こと。

### TC-E2E-02: ログベースアラートと通知チャネルの紐付け

- **手順**:
  1. `alert_definitions` シートに定義した条件のログを生成。
  1. `notifications` シートで定義した各メールアドレスに通知が届くか確認。
- **期待結果**: `monitoring_notification_channels` がアラートポリシーに正しく紐付いており、全通知先にメールが配信されること。
