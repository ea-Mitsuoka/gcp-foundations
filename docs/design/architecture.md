# アーキテクチャ設計書 (GCP Foundations)

本ドキュメントでは、本リポジトリで構築されるGCP環境の全体像、設計思想、および運用設計について解説します。

______________________________________________________________________

## 1. 設計思想 (Core Philosophy)

本基盤は、大規模な組織運用に耐えうる「堅牢性」と、誰が実行しても同じ結果が得られる「再現性」を重視して設計されています。

- **Single Source of Truth (SSOT)**: すべての構成（プロジェクト名、API、IAM等）はスプレッドシート (`gcp_foundations.xlsx`) で一元管理されます。
- **ランダム要素の排除**: プロジェクト ID 等に `random_id` を使用せず、命名規則に基づいた確定的な ID を付与することで、冪等性を担保します。
- **宣言的なインフラ管理**: `csvdecode` や `for_each` を活用し、データからリソースを動的に生成します。外部スクリプトへの依存を最小限に抑え、Terraform ネイティブな記述を優先します。

______________________________________________________________________

## 2. リソース階層と全体像

```mermaid
flowchart TD
    subgraph Org [Google Cloud Organization]
        direction TB

        %% 管理プロジェクトレイヤー（上側）
        subgraph Core [共有管理レイヤー]
            direction LR
            LogSink[LogSink プロジェクト<br/>ログ集約・監査]
            Mon[Monitoring プロジェクト<br/>統合監視・アラート]
            Net[VPC ホスト プロジェクト<br/>共通ネットワーク管理]
        end

        %% ワークロードレイヤー（下側）
        subgraph Workloads [ワークロードレイヤー]
            direction LR
            Prod[Production<br/>本番環境プロジェクト]
            Dev[Development<br/>開発環境プロジェクト]
        end

        %% 関係性
        %% 監視・統制（上から下）
        Mon ==>|監視スコープ設定| Prod
        Mon ==>|監視スコープ設定| Dev
        Net --- Prod
        Net --- Dev

        %% データフロー（下から上へのログ転送などは点線で表現）
        Prod -.->|ログ転送| LogSink
        Dev -.->|ログ転送| LogSink
    end

    %% スタイル定義
    style Org fill:#f9f9f9,stroke:#333,stroke-width:2px
    style Core fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    style Workloads fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
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

______________________________________________________________________

## 3. セキュリティとガバナンス

- **組織ポリシー**: 外部 IP の制限やデフォルト VPC の作成禁止などを組織レベルで強制。
- **サービスアカウント借用 (Impersonation)**: JSON キーを直接扱わず、セキュアな認証フローを採用。
- **ログ集約**: 全プロジェクトの監査ログを中央プロジェクトの BigQuery/GCS に自動転送。

______________________________________________________________________

## 4. 運用・自動化

- **`uv` による実行環境管理**: Python スクリプトの実行環境を固定し、実行者による差異を排除。
- **一括デプロイ (`make deploy`)**: 複雑な依存関係を持つ複数レイヤーを、順序正しく自動展開。
