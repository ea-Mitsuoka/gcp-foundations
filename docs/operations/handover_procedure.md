# 顧客への引き渡し (Handover) 手順

本ドキュメントでは、構築した GCP 基盤および IaC リポジトリを最終的に顧客（本来のインフラ管理者）へ引き渡す際の手順を説明します。

______________________________________________________________________

## 1. 納品成果物の作成 (make delivery)

`make delivery` を実行すると、**元リポジトリ（`.git`・作業ツリー）には一切手を加えず**、一時コピー上でクリーンな Git ツリーを作成し、`delivery/` 配下に納品成果物を出力します。

```bash
make delivery
```

内部処理：

1. `terraform/scripts/generate_delivery.py` が構築設定明細書を `delivery/GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx` として生成します（前段。詳細は「6. 納品物（構築設定明細書）の自動生成」）。
1. `terraform/scripts/handover.sh` が作業ツリーを一時領域へコピーし、`.gitignore` を納品用に調整 → `git init` → `commit` → 不要ファイルを除去（`git clean`）→ `.git` 込みで zip 化し、**Initial commit が 1 つだけのクリーンなリポジトリ** `delivery/gcp-foundations_<YYYYMMDD>.zip` を出力します。**元の `.git` は保持されます。**

> 旧版のように `.git` を削除して履歴を作り直すことはしません（誤実行による事故防止）。**本番の作業リポジトリでそのまま実行して問題ありません。**

顧客へは `delivery/` 配下の**2ファイル**を提供します（zip に明細書 xlsx は含まれません。別ファイルとして渡します）：

- `GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx`（構築設定明細書）
- `gcp-foundations_<YYYYMMDD>.zip`（IaC 一式。下記方針でファイルを取捨選択済み）

### 納品 zip に含まれるもの／含まれないもの

**含む（顧客が環境を再現・運用するために必要）:**

- IaC テンプレート一式、自動生成コード（`auto_*.tf`）
- 環境固有のソース設定：`terraform/common.tfvars`、`terraform/common.tfbackend`、`domain.env`、`gcp-foundations.xlsx`
- 運用ドキュメント：`docs/setup/`、`docs/operations/`（一部除く）、`docs/reference/`、`docs/design/`（architecture / data-dictionary / iam_management_scope）

**含まない（社内限定・顧客の運用には不要）:**

- `docs/development/`、`docs/tests/`、`docs/ea-design/`、`docs/migration/`
- `docs/design/todo.md`、`docs/design/generator_philosophy.md`
- `docs/operations/module_maintenance.md`、`delivery_document_generation.md`、`spreadsheet_session_guide.md`
- `tfstate`、ローカルキャッシュ（`.terraform/` 等）、`.venv`、構築設定明細書（xlsx は zip とは別に提供）

### 顧客側での受け取り後のセットアップ

顧客（運用担当者）が受け取り後に行う認証・権限取得・差分確認（`make generate` → `make plan`）・Git 管理開始の手順は、納品物に同梱される **[運用引き継ぎ・セットアップ手順](./operational_takeover.md)** にまとめてある。引き渡し時はこれを案内する。

### 引き渡し前チェック：削除保護（allow_resource_destruction）

通常は **削除保護を有効（`allow_resource_destruction = false`）にした状態で引き渡す**のが安全です。引き渡し前に実環境へ適用してから納品します。

```bash
# common.tfvars を allow_resource_destruction = false に変更したうえで
make generate     # deletion_protection = true を全リソースに反映
make deploy       # 実環境に削除保護を適用（顧客の初回 make plan の差分も防止）
make delivery     # 保護 ON の状態の common.tfvars をそのまま同梱
```

> `make delivery` は、`common.tfvars` が `allow_resource_destruction = true`（保護 OFF）のままだと**警告して続行可否を対話確認**します（`handover-wrap.sh` による非破壊チェック。apply はしません）。意図的に保護 OFF で渡す場合のみ続行してください。非対話実行（CI 等）で続行するには `DELIVERY_ALLOW_DESTRUCTION_ACK=1` を指定します。

______________________________________________________________________

## 2. GCP 権限の移譲 (IAM)

Terraform 実行基盤（Layer 0: Bootstrap）で作成したリソースの管理権限を顧客の管理者へ移譲する（引き渡し側の作業）。

1. **顧客への権限付与**: 顧客の管理者ユーザー（または Google グループ）へ運用に必要なロールを付与する。付与するロールは [運用引き継ぎ・セットアップ手順「1.2 運用担当者に必要な権限」](./operational_takeover.md) を参照。
1. **構築者の権限剥奪**: 顧客自身でコンソールアクセスや `make deploy` を実行できることを確認した後、構築者自身のアカウントの IAM バインディングを削除する。

______________________________________________________________________

## 3. 納品物の確認

引き渡し時に以下のものが揃っていることを確認してください。

1. **IaC 一式 (zip)**: `gcp-foundations_<YYYYMMDD>.zip`。社内限定ドキュメント・tfstate・キャッシュを除外済み。
1. **構築設定明細書**: `GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx`（zip とは別ファイル）。
1. **SSoT (Excel)**: `gcp-foundations.xlsx`（zip に同梱）。現在の環境と一致していること。
1. **ドキュメント**: zip 内 `docs/` の運用マニュアル一式（社内限定分は除外済み）。

______________________________________________________________________

## 4. CI/CD パイプライン（GitHub Actions）の有効化

ドリフト自動検知や PR 時の自動 Plan を行う GitHub Actions の有効化手順（WIF 構築・ワークフロー設定・GitHub Secrets 登録）は、納品物に同梱される **[運用引き継ぎ・セットアップ手順「2. CI/CD パイプライン（GitHub Actions）の有効化」](./operational_takeover.md)** に記載。引き渡し時はこれを顧客へ案内する。

______________________________________________________________________

## 5. 後任者によるセットアップ

リポジトリを受け取った運用担当者のセットアップ（認証・権限取得・設定ファイル復元）は、納品物に同梱される **[運用引き継ぎ・セットアップ手順](./operational_takeover.md)** および **[後任者・リカバリガイド (Recovery & Succession)](./recovery_and_succession.md)** を参照。

______________________________________________________________________

## 6. 納品物（構築設定明細書）の自動生成

`make delivery` 実行時（または単体で `make delivery-doc`）、SSoT である `gcp-foundations.xlsx` と `terraform/common.tfvars` / `domain.env` を読み取り、日本のシステム開発における一般的な「設計・設定明細書」様式の Excel を `delivery/GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx` として自動生成します（生成スクリプト: `terraform/scripts/generate_delivery.py`）。

シート構成・判定ロジック・表紙メタ情報の上書き方法など、機能の詳細は以下を参照してください。

- **[納品物（構築設定明細書）自動生成 機能説明](./delivery_document_generation.md)**

> `delivery/` はテンプレートリポジトリでは `.gitignore` 対象（顧客固有データを含むため）ですが、`handover.sh` が除外を解除するため、顧客への納品リポジトリ（`make delivery` 後の `Initial commit`）には同梱されます。
