# 納品物（構築設定明細書）自動生成 機能説明

本ドキュメントは、本リポジトリに搭載されている **納品物（構築設定明細書）の自動生成機能** の仕様・仕組み・カスタマイズ方法を説明する機能説明資料です。

> 引き渡し作業そのものの手順は **[顧客引き渡し手順](./handover_procedure.md)** を参照してください。本書はその中で使われる「納品物生成」機能の解説に特化しています。

______________________________________________________________________

## 1. 概要

本機能は、SSoT（`gcp-foundations.xlsx`）と `terraform/common.tfvars` / `domain.env` を入力として、日本のシステム開発で一般的な「設計・設定明細書」様式の Excel ファイルを **毎回その時点の内容で自動生成** します。手書き・手作業の整形は不要です。

- 生成スクリプト: `terraform/scripts/generate_delivery.py`
- 出力先: `delivery/GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx`
- 実行: `make delivery`（引き渡し処理の直前に自動実行）または `make delivery-doc`（生成のみ）

### 設計上の方針

- **SSoT を単一の事実源とする**: 内容はすべて Excel / `common.tfvars` に由来し、ドキュメントへ独自の事実を書き足さない（二重管理を避ける）。
- **虚偽の「完了」を出さない**: 「構築項目一覧」の実施状況は SSoT の定義有無から機械的に判定し、定義がない項目は `完了` ではなく `—` と表示する。
- **顧客固有データを誤って共有しない**: 生成物（`delivery/`）はテンプレートリポジトリでは Git 追跡対象外。引き渡し時のみ顧客リポジトリへ同梱される（後述）。

______________________________________________________________________

## 2. 入力（データソース）

| 入力ファイル | 参照する内容 |
| --- | --- |
| `gcp-foundations.xlsx`（SSoT） | `resources`（フォルダ／プロジェクト）、`org_policies`、`log_sinks`、`alert_definitions`、`notifications`、`shared_vpc_subnets`、`vpc_sc_perimeters`、`tag_definitions` |
| `terraform/common.tfvars` | 組織ドメイン・プロジェクトID接頭辞・請求先アカウント・リージョン・各種フラグ（`enable_shared_vpc` / `enable_vpc_host_projects` / `enable_org_policies` / `enable_tags` / `allow_resource_destruction` 等） |
| `domain.env` | 組織ドメイン（`common.tfvars` に無い場合のフォールバック） |

> 各プロジェクトの `terraform/4_projects/<name>/terraform.tfvars` は **読み込みません**。tfvars 自体が SSoT から `make generate` で生成される派生物のため、上流の SSoT を直接参照しています。

> 管理用 Google グループとその組織レベル IAM ロール（シート10）は SSoT には存在せず、`terraform/2_organization/main.tf` の `locals.raw_roles` を `generate_delivery.py` 内に転記して反映しています。集約／フルモードの切替（`enable_simplified_admin_groups`）と適用有無（`enable_group_iam`）は `common.tfvars` の値で判定します。terraform 側のロール定義を変更した場合は、スクリプト側の `GROUP_ROLES` も更新してください。

______________________________________________________________________

## 3. 出力（シート構成）

| シート | 内容 |
| --- | --- |
| 表紙 | 顧客名・対象組織ドメイン・組織ID・文書番号・版数・作成日・作成者・提供元・承認欄（押印枠） |
| 改訂履歴 | 版数／改訂日／改訂内容（初版を自動記載） |
| 目次 | 各章（1〜11）への索引 |
| 1. 構築項目一覧 | 組織取り込み・Cloud Identity・課金リンク・管理フォルダ・管理プロジェクト・組織ポリシー・ログ集約・集中モニタリング・予算アラート・ネットワーク・タグ／ラベルの実施総括 |
| 2. 構築概要 | 環境情報（接頭辞・課金・リージョン・各種フラグ）と管理プロジェクト一覧 |
| 3. フォルダ構成 | フォルダ階層（フォルダ名／親） |
| 4. プロジェクト一覧 | 表示名・配置先・環境・取り込み元ID・集中監視／ログ・予算・予算通知先 |
| 5. 組織ポリシー | 適用対象・ポリシーID・強制・許可リスト・適用モード |
| 6. ログ集約シンク | ログ種別・フィルタ・宛先種別・宛先・保持日数 |
| 7. 監視・予算 | 7-1 アラート定義／7-2 通知先／7-3 予算アラート |
| 8. ネットワーク | 8-1 Shared VPC サブネット／8-2 VPC-SC 境界 |
| 9. タグ・ラベル | 9-1 組織タグ定義（`tag_definitions`）／9-2 プロジェクト別 ラベル(`app`/`env`/`owner`)・適用タグ(`org_tags`) |
| 10. Google グループ・IAM | 管理用 Google グループと付与される組織レベル IAM ロール（集約／フルモード・`enable_group_iam` の適用状態を反映） |
| 11. 費用注意事項 | コストが増加しやすい設定（Data Access 監査ログ集約・VPC フローログ・シンク先 BigQuery/GCS・Monitoring 取り込み等）の注意事項と抑制策 |

### 判定ロジックの要点

- **実施状況（1. 構築項目一覧）**: 対応する SSoT の定義が存在すれば `完了`、無ければ `—`。
  例）`resources` にフォルダ行が無ければ「管理フォルダ構成 → —」。
- **ラベル（9-2）**: GCP プロジェクトの `labels`。`app`（= `resource_name`）は常に付与、`env` / `owner` は SSoT に値がある場合のみ付与（空欄は付与なし）。`make generate` が生成する `terraform.tfvars` の挙動と一致します。
- **組織タグ（9-1）**: 組織レベルのタグ。`common.tfvars` の `enable_tags` 有効時に組織へ作成され、各プロジェクトの `org_tags`（`key/value` 形式）に基づき紐付けられます。

______________________________________________________________________

## 4. カスタマイズ（表紙メタ情報）

SSoT に存在しない表紙のメタ情報（顧客名・作成者・版数等）のみ、環境変数で上書きできます。未指定時はプレースホルダが入ります。

```bash
DELIVERY_CUSTOMER="〇〇株式会社" DELIVERY_AUTHOR="氏名" DELIVERY_VERSION="1.0" make delivery-doc
```

| 環境変数 | 既定値 |
| --- | --- |
| `DELIVERY_CUSTOMER` | （顧客名を記入） |
| `DELIVERY_VENDOR` | 株式会社イー・エージェンシー |
| `DELIVERY_AUTHOR` | （作成者を記入） |
| `DELIVERY_VERSION` | 1.0 |
| `DELIVERY_DOCNO` | `GCP-FND-<YYYYMMDD>` |

______________________________________________________________________

## 5. `make delivery` との統合と Git 追跡

```
make delivery
  ├─ ① make delivery-doc   … generate_delivery.py で納品物を delivery/ に生成
  └─ ② handover.sh          … .gitignore の delivery/ 除外を解除 → git 履歴リセット → Initial commit
```

- `delivery/` はテンプレートリポジトリの `.gitignore` 対象です（顧客固有データを含むため、開発時に誤ってコミットしない）。
- `handover.sh` が引き渡し時に限り `delivery/` の除外を解除するため、顧客への納品リポジトリ（`make delivery` 後の `Initial commit`）には **同梱** されます。

> **⚠️ 機微情報の取り扱い**: 生成物には請求先アカウントID・組織ID・予算/通知アラートのメールアドレス等が含まれます。顧客への納品物としては適切な内容ですが、社外への共有・保管は各社のデータ取扱いポリシーに従ってください（テンプレートリポジトリでは `.gitignore` により誤コミットを防止しています）。

______________________________________________________________________

## 6. テスト

`tests/test_generate_delivery.py`（`make test-py` / CI の `pytest tests/` で実行）が以下を検証します。

- 最小 SSoT からの生成で、全シートが揃うこと。
- 「構築項目一覧」の実施状況が SSoT 定義有無に従うこと（例: サブネット/境界なし → ネットワークは `—`）。
- ラベル（`app` は常に、`env`/`owner` は値がある時のみ）が整形されること。
- グループ／IAM が `enable_simplified_admin_groups` / `enable_group_iam` を反映すること。
- **ドリフト検知**: `GROUP_ROLES` が `terraform/2_organization/main.tf` の `raw_roles` と一致すること（terraform 側だけ変更すると CI が落ちる）。

______________________________________________________________________

## 7. 関連ドキュメント

- **[顧客引き渡し手順](./handover_procedure.md)**: 本機能を含む引き渡し全体の手順
- **[スプレッドシートの仕様書](../setup/spreadsheet_format.md)**: 入力となる SSoT のカラム定義
- **[自動生成エンジンの設計思想](../design/generator_philosophy.md)**: `make generate` の内部設計・拡張方針
