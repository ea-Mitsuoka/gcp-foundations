# 課金アカウントのリンク設定

## 課金アカウントリンクに必要なIDを取得

```bash
export PROJECT_ID=$(gcloud projects list --filter="name:your-project-name" --format="value(projectId)")
export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)

echo $PROJECT_ID
echo $BILLING_ACCOUNT_ID
```

## 課金アカウントをリンク

```bash
gcloud billing projects link ${PROJECT_ID} \
      --billing-account=${BILLING_ACCOUNT_ID}
```

## プロジェクト命名

プロジェクトの命名は、Single Source of Truth (SSOT) の原則に基づき、ルートディレクトリの domain.env で定義されたドメイン名から自動的に算出されます。
外部モジュール等への依存はなく、ドメイン名のドットをハイフンに変換した文字列が接頭辞として付与されます。

例: domain.env に domain="example.com" が設定されている場合

- example-com-logsink
- example-com-monitoring

______________________________________________________________________

## 補足: `1_core/base` ディレクトリの役割

このディレクトリは、GCP基盤における**レイヤー1 (`1_core`)** の一部であり、組織全体で共有されるコアサービスの「土台（Base）」となるGCPプロジェクトを作成する責務を担います。

## 役割

ここで作成されるのは、機能の実装を持たない、空のGCPプロジェクト（器）です。具体的な機能（サービス）は、`../services` ディレクトリで、ここで作成されたプロジェクトに対して実装されます。

現在、以下の共有プロジェクトが作成されます。

- **`logsink/`**: 組織全体のログを集約・管理するためのプロジェクト。
- **`monitoring/`**: 組織全体の監視とアラートを一元管理するためのプロジェクト。

## 実装

各サブディレクトリは、ルートの`modules/project-factory`モジュールを呼び出し、一貫した命名規則と設定でプロジェクトを作成します。

より詳細な設計思想については、リポジトリのルートにある`README.md`の「📖 設計思想」セクションを参照してください。
