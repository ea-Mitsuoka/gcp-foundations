# テスト実行フローガイド (Setup, Teardown & Transitions)

本ドキュメントでは、`test_specification.md` に定義された各テストケース（TC-000〜TC-051）を実行する際の、テスト間の遷移、環境の準備、およびクリーンアップ手順を詳細に定義します。

## 1. 全体的な指針

- **コード生成のクリーンアップ**: `make generate` を実行すると、前回生成された `auto_*.tf` ファイルは自動的に削除されるため手動削除は不要です。
- **GCPリソースのクリーンアップ (超重要)**: 新しい正常系のExcel（フィクスチャ）に差し替える際は、古いExcelの定義で作成されたリソースが残っていると、Terraformの削除保護（`PREVENT`）機能により確実にデッドロックエラーが発生します。フェーズの移行時など、不要になるリソースがある場合は、**Excelを差し替える前に必ず `make destroy` で更地にしてください**。
- **状態の引き継ぎ**: 特に指定がない限り、同じExcelを編集していくテスト（例: TC-001〜TC-003）は「前のテストが完了した状態」から差分デプロイで開始します。

______________________________________________________________________

## 2. 各テスト間の遷移手順

### Phase 0: 初期構築

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| (開始) | **TC-000a** | GCP組織管理者権限でログインし、組織ID、課金IDを準備する。 |
| **TC-000a** | **TC-000b** | `common.tfvars` が生成されていること、および **`billing_account_id` が本物の課金IDになっていること**を確認。権限不足の別アカウントに切り替えて検証。 |
| **TC-000b** | **TC-000c** | 元の管理者アカウントに戻る。`make install` が完了していることを確認。 |
| **TC-000c** | **TC-000d** | ローカルで意図的なエラーを混入させ、GitHubへPushしてPRを作成する。 |

### Phase 1: 基本リソース

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-000d** | **TC-001** | `TC001_to_003_Basic.xlsx` を `gcp-foundations.xlsx` としてコピー。**TC-002, 003用の行（フォルダや予算）を一旦削除・空欄にし、最小構成の1行のみにする。** |
| **TC-001** | **TC-002** | `resources` シートに TC-002 用の行（フォルダと子プロジェクト）を追記する。 |
| **TC-002** | **TC-003** | `resources` シートの既存行に `budget_amount` を追記する。 |
| **TC-003** | **TC-004** | ⚠️ **環境リセットを行わずに** `TC004_to_009_Validation_Err.xlsx` に差し替える（これ以降は `make generate` のみが走り、デプロイは行われないためリソースは影響を受けない）。 |
| **TC-004** | **TC-005** | 不正な名称を修正し、セル内に全角スペースや改行を混入させる。 |
| **TC-005** | **TC-006** | `resources` シートに同一のリソース名（プロジェクト）を2つ記述。 |
| **TC-006** | **TC-007** | 重複を解消し、次はフォルダとプロジェクトで同じ名前を記述。 |
| **TC-007** | **TC-008** | 名前の重複を解消し、`parent_name` に存在しないフォルダ名を記述。 |
| **TC-008** | **TC-009** | 親フォルダ名を修正し、自分自身を親（循環参照）にする設定を行う。 |

### Phase 2: ネットワーク (Shared VPC)

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-009** | **TC-010** | ⚠️ **【最重要：異常系テストからの回復】**<br>直前のテスト(TC-004〜009)で `make generate` が意図的に失敗しているため、**自動生成された変数ファイル(`auto_*.tf`)がリポジトリから削除された状態**になっています。このままでは `make destroy` が変数未定義エラーで失敗するため、以下の回復手順が必須です。<br><br>1. **正常なExcelで変数を再生成:**<br> `cp tests/fixtures/TC001_to_003_Basic.xlsx gcp-foundations.xlsx`<br> `make generate`<br>2. **リソースの完全消去:**<br> `common.tfvars` で `allow_resource_destruction=true` を確認。<br> `make destroy ALL`<br>3. **次期テストの準備:**<br> `TC010_016_019_Network_Success.xlsx` を `gcp-foundations.xlsx` にコピー。<br> `common.tfvars` で `enable_shared_vpc = true` に設定。 |
| **TC-010** | **TC-011** | ⚠️ デプロイは行わないため、**リソースは残したまま** `TC011_012_014_015_018_Network_Err.xlsx` に差し替え（重複CIDRの確認）。 |
| **TC-011** | **TC-012** | 重複CIDRを解消し、存在しないサブネット名を `resources` シートに入力。 |
| **TC-012** | **TC-013** | `common.tfvars` の `enable_shared_vpc` を `false` に変更。 |
| **TC-013** | **TC-014** | `shared_vpc_subnets` シートに不正なIP形式（300/24等）を入力。 |
| **TC-014** | **TC-015** | IP形式を修正し、ホストビットが立ったIP（10.0.1.5/24等）を入力。 |
| **TC-015** | **TC-016** | ネットワークエラーExcelを破棄し、再び `TC010...Success.xlsx` に戻して `prod` / `dev` 両方のサブネット定義がある状態にする。 |
| **TC-016** | **TC-017** | `common.tfvars` で `enable_vpc_host_projects = false` に変更。 |
| **TC-017** | **TC-018** | `resources` シートで `folder` 種別の行にサブネット名を入力。 |
| **TC-018** | **TC-019** | `resources` シートからサブネット参照を消し、`shared_vpc_subnets` シートのみにデータを残す。 |

### Phase 3: ガバナンス

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-019** | **TC-020** | ⚠️ **【重要】** `make destroy` でPhase 2のリソースを完全に更地にする。<br>その後、`TC020_to_022_026_Governance_Success.xlsx` に差し替え。`common.tfvars` で `enable_vpc_sc = true` に設定。 |
| **TC-020** | **TC-021** | `org_policies` シートにデータを追記。`common.tfvars` の `enable_org_policies = true` を確認。 |
| **TC-021** | **TC-022** | `tag_definitions` と `resources` の `org_tags` を追記。`common.tfvars` の `enable_tags = true` を確認。 |
| **TC-022** | **TC-023** | ⚠️ リソースは残したまま、`TC023_024_025_027_028_Governance_Err.xlsx` に差し替え。 |
| **TC-023** | **TC-024** | タグ値を修正し、`resources` シートの `vpc_sc` 列に未定義の境界名を入力。 |
| **TC-024** | **TC-025** | 境界名を修正し、`org_policies` シートの適用先（target）に存在しない名前を入力。 |
| **TC-025** | **TC-026** | `org_policies` シートの `enforce` を空にし、`allow_list` に値を入力。 |
| **TC-026** | **TC-027** | `resources` シートの `org_tags` を `env:prod`（コロン区切り）などの不正形式にする。 |
| **TC-027** | **TC-028** | `policies/require_labels_test.rego` を作成（または fixtures から配置）。 |
| **TC-028** | **TC-029** | `make opa` を実行し構文チェック。 |

### Phase 4: 運用・ライフサイクル

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-029** | **TC-030** | エラー検証用Excelを破棄し、`TC020...Success.xlsx`（正常系）に戻す。<br>Excel上で既存フォルダの `resource_name` を書き換える。 |
| **TC-030** | **TC-030b**| `common.tfvars` で `allow_resource_destruction = false` を確認。`project_id_prefix` を変更。 |
| **TC-030b** | **TC-031** | `common.tfvars` を `allow_resource_destruction = true` に変更し一度 `make deploy`（保護解除反映）。 |
| **TC-031** | **TC-032** | `make destroy` を実行（全消去の準備）。 |
| **TC-032** | **TC-033** | `allow_resource_destruction = false` に戻し、再度 `make destroy` を試みる。 |
| **TC-033** | **TC-034** | `allow_resource_destruction = true` に設定。`make deploy` でリソースがある状態にする。 |
| **TC-034** | **TC-035** | `make destroy LAYER=2` を実行（L4, L3, L2 が消えることを確認）。 |
| **TC-035** | **TC-036** | `make destroy LAYER=1` を実行（L1 Services も消えることを確認）。 |
| **TC-036** | **TC-037** | `make destroy ALL` を実行（管理プロジェクトの器ごと削除）。 |
| **TC-037** | **TC-038** | `make deploy` で再構築後、コンソールで手動変更（タグ削除等）を行う。 |
| **TC-038** | **TC-039** | `make clean` を実行。 |

### Phase 5: ログ・監視

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-039** | **TC-040** | ⚠️ **【重要】** `make destroy ALL` でPhase 4のリソースを完全に更地にする。<br>その後、`TC040_to_041_Logging_Success.xlsx` に差し替え。 |
| **TC-040** | **TC-041** | `allow_resource_destruction = true` を確認。`make destroy` 実行時のデータ削除挙動を確認。 |
| **TC-041** | **TC-042** | `TC042_to_043_Logging_Err.xlsx` に差し替え（アラート定義重複）。 |
| **TC-042** | **TC-043** | `alert_documentation` 列の値を削除して空にする。 |

### Phase 6: 納品

| 現在のテスト | 次のテスト | 遷移作業・準備 |
| :--- | :--- | :--- |
| **TC-043** | **TC-050** | `common.tfvars` の `core_billing_linked = false` に設定。デプロイ後、`true` に戻して再実行。 |
| **TC-050** | **TC-051** | 全ての構築・検証が完了した状態で、`make delivery` を実行。 |

______________________________________________________________________

## 3. 注意事項

- **破壊的操作の慎重な実行**: `make destroy` を含むテストは、管理プロジェクトや組織レベルの設定を削除するため、実行前に必ずバックアップや、対象組織が正しいことを確認してください。
- **tfstateの保護**: `0_bootstrap` レイヤー（L0）は `make destroy ALL` でも削除されません。これを削除する場合は手動でバケットとプロジェクトを削除する必要があります。
- **API伝播時間**: プロジェクト作成やAPI有効化の直後は、GCP内部の伝播に数分かかる場合があります。エラーが出た場合は少し待ってから再試行してください。
