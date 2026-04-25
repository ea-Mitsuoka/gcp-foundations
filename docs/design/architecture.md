# アーキテクチャ設計書 (GCP Foundations)

本ドキュメントでは、本リポジトリで構築されるGCP環境の全体像、設計思想、および運用設計について解説します。

---

## 1. 設計思想 (Core Philosophy)

本基盤は、大規模な組織運用に耐えうる「堅牢性」と、誰が実行しても同じ結果が得られる「再現性」を重視して設計されています。

- **Single Source of Truth (SSOT)**: すべての構成（プロジェクト名、API、IAM等）はスプレッドシート (`gcp_foundations.xlsx`) で一元管理されます。
- **ランダム要素の排除**: プロジェクト ID 等に `random_id` を使用せず、命名規則に基づいた確定的な ID を付与することで、冪等性を担保します。
- **宣言的なインフラ管理**: `csvdecode` や `for_each` を活用し、データからリソースを動的に生成します。外部スクリプトへの依存を最小限に抑え、Terraform ネイティブな記述を優先します。

---

## 2. リソース階層と全体像

```mermaid
graph TD
    subgraph Organization [GCP Organization]
        direction TB
        subgraph Core_Folder [Folder: Shared / Core]
            LogSink_Proj[Project: LogSink]
            Mon_Proj[Project: Monitoring]
            VPC_Host[Project: VPC-Host]
        end

        subgraph Workload_Folder [Folder: Workloads]
            Prod_Folder [Folder: Production]
            Dev_Folder [Folder: Development]
        end
    end
```

### レイヤー構造 (Deployment Layers)
変更の影響を局所化するため、以下の5段階でデプロイを行います。

| Layer | 名称 | 役割 |
| :--- | :--- | :--- |
| **0** | **Bootstrap** | Terraform 実行基盤 (tfstate バケット等) の作成 |
| **1** | **Core Services** | ログ集約、統合監視、VPC ホストプロジェクトの作成 |
| **2** | **Organization** | 組織ポリシー、組織 IAM、VPC-SC 境界の定義 |
| **3** | **Folders** | 環境分離のためのフォルダ構造構築 |
| **4** | **Projects** | アプリケーション用プロジェクトの展開 |

---

## 3. セキュリティとガバナンス

- **組織ポリシー**: 外部 IP の制限やデフォルト VPC の作成禁止などを組織レベルで強制。
- **サービスアカウント借用 (Impersonation)**: JSON キーを直接扱わず、セキュアな認証フローを採用。
- **ログ集約**: 全プロジェクトの監査ログを中央プロジェクトの BigQuery/GCS に自動転送。

---

## 4. 運用・自動化

- **`uv` による実行環境管理**: Python スクリプトの実行環境を固定し、実行者による差異を排除。
- **一括デプロイ (`make deploy`)**: 複雑な依存関係を持つ複数レイヤーを、順序正しく自動展開。
