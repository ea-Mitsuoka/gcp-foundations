お疲れ様でした。実装した機能の運用方法、監視内容、そして期待されるアクションについて、以下にまとめます。

-----

## 運用方法

この仕組みは、一度設定すれば**基本的に自動で運用**されます。手動での定期的な作業は必要ありません。

1.  [cite\_start]**毎日午前3時**に、Cloud SchedulerがCloud Functionを自動的にトリガーします [cite: 50]。
2.  トリガーされたCloud Functionは、BigQueryビューをクエリして非アクティブなアカウント数を計算し、その結果をCloud Monitoringのカスタム指標に書き込みます。
3.  Cloud Monitoringは、その指標の値を常に監視します。

運用担当者の主なタスクは、後述する**アラートが発生した際に、適切に対応すること**です。

-----

## 監視できること

この仕組みは、以下の条件に合致する\*\*「非アクティブなユーザーアカウント」\*\*を監視します。

  * **何を:** 組織、フォルダ、またはプロジェクトレベルで何らかのIAM権限を付与されている**ユーザーアカウント**（サービスアカウントは除く）。
  * **どのような状態を:** 過去90日以上にわたって、**一切の管理アクティビティ監査ログに記録される操作を行っていない**状態。

具体的には、Cloud Asset Inventoryが保持する「権限を持つユーザーのリスト」と、監査ログが保持する「過去90日間に活動したユーザーのリスト」を比較し、前者にのみ存在し後者には存在しないユーザーを「非アクティブ」として検知します。

-----

## 期待されるアクション（アラート発生時の対応）

非アクティブなアカウントが1件以上検知されると、設定した通知先にアラートが送信されます。アラートを受け取った際に期待されるアクションは以下の通りです。

1.  **非アクティブなアカウントの特定**

      * `logsink`プロジェクト (`mtskykhd-tokyo-logsink-b92d`) のBigQueryに移動します。
      * 以下のクエリを実行し、どのアカウントが非アクティブであるかを特定します。
        ```sql
        SELECT * FROM `mtskykhd-tokyo-logsink-b92d.security_analytics.inactive_users_view`;
        ```

2.  **調査**

      * 特定されたアカウントが、現在もその権限を必要としているかを確認します。
          * そのユーザーはまだ在籍していますか？
          * 長期休暇中ではありませんか？
          * その役職や業務内容に、そのIAM権限は本当に必要ですか？

3.  **対処**

      * **権限が不要な場合:** 最小権限の原則に基づき、**不要なIAMロールを剥奪**します。
      * **アカウントが不要な場合（退職者など）:** Google Workspaceなどの中央ID管理システムで、**アカウントを無効化または削除**します。
      * **権限が必要な場合:** なぜ90日間活動がなかったのか理由を記録し、例外として扱います。

この仕組みを運用することで、不要になった権限を定期的に棚卸しし、組織全体のセキュリティリスク（攻撃対象領域）を継続的に低減させることが可能になります。


`asset_inventory_bq_export`の設定も含めた、ゼロからデプロイを完了させるまでの完全な手順を改めてまとめます。

-----

## 概要

デプロイは大きく分けて5つのフェーズで実行します。

1.  **フェーズ1：初期構築（Bootstrap & Core Projects）**
2.  **フェーズ2：`logsink`プロジェクトのサービス設定**
3.  **フェーズ3：`monitoring`プロジェクトのサービス設定**
4.  **フェーズ4：関数ソースコードの準備とアップロード**
5.  **フェーズ5：`inactive_accounts`機能の段階的デプロイ**

-----

### フェーズ1：初期構築（Bootstrap & Core Projects）

  * **前提:**
      * `0_bootstrap`モジュールが適用済みであること。（TF-Adminプロジェクト、GCSバケットなどが作成済み）
      * `1_core/base/logsink`と`1_core/base/monitoring`モジュールが適用済みであること。（`logsink`と`monitoring`プロジェクトが作成済みで、請求先アカウントがリンク済み）

-----

### フェーズ2：`logsink`プロジェクトのサービス設定

`logsink`プロジェクトで、ログとアセット情報を受け入れるためのAPIとサービスを有効化します。

1.  **APIを有効化する**

      * **場所:** `terraform/1_core/services/logsink/google_project_service/`
      * **目的:** `logsink`プロジェクトでBigQuery, Pub/Sub, Cloud Asset APIなどを有効化します。
      * **実行:** このディレクトリで`terraform apply`を実行します。

2.  **Asset Inventoryのエクスポートを設定する**

      * **場所:** `terraform/1_core/services/logsink/asset_inventory_bq_export/`
      * [cite\_start]**目的:** 組織内のIAMポリシーの変更をリアルタイムで検知し、`logsink`プロジェクトのBigQueryデータセット\*\*`asset_inventory`\*\*にエクスポートする設定です [cite: 75, 77]。関数が分析に使うデータソースの一つです。
      * **実行:** このディレクトリで`terraform apply`を実行します。

3.  **組織ログシンクを設定する**

      * **場所:** `terraform/1_core/services/logsink/sinks/`
      * **目的:** 組織全体の監査ログなどを`logsink`プロジェクトのBigQueryデータセット\*\*`sink_logs`\*\*に集約する設定です。
      * **実行:** このディレクトリで`terraform apply`を実行します。

-----

### フェーズ3：`monitoring`プロジェクトのサービス設定

`monitoring`プロジェクトで、Cloud Functionのビルドと実行に必要なAPIとIAM権限を適用します。

1.  **APIを有効化する**

      * **場所:** `terraform/1_core/services/monitoring/google_project_service/`
      * **目的:** `monitoring`プロジェクトでCloud Functions, Cloud Build, Scheduler, BigQueryなどのAPIを有効化します。
      * **実行:** このディレクトリで`terraform apply`を実行します。

2.  **サービスエージェント等にIAM権限を付与する**

      * **場所:** `terraform/1_core/services/monitoring/iam/`
      * **目的:** ビルドを実行する**Compute Engineのデフォルトサービスアカウント**などに対して、ビルドとデプロイに必要な一連の権限 (`Cloud Run 管理者` `Artifact Registry 書き込み/読み取り`など) を付与します。
      * **実行:** このディレクトリで`terraform apply`を実行します。
      * **反映待機:** IAMの変更がGCP全体に反映されるまで**60秒ほど待機**します。

-----

### フェーズ4：関数ソースコードの準備とアップロード

修正済みのPythonコードを準備し、GCSバケットにアップロードします。

1.  **ソースコードを修正・確認する**

      * `inactive_accounts/function_source/main.py`の関数定義が`def check_inactive_accounts(request):`となっていること、関数の最後に`return`文があることなどを確認します。

2.  **ソースコードをZIP化してアップロードする**

      * `function_source`ディレクトリの親ディレクトリから、以下のコマンドを順番に実行します。

    <!-- end list -->

    ```bash
    cd terraform/1_core/services/monitoring/9_custom_checks/inactive_accounts/function_source
    zip ../function_source.zip ./*
    gcloud storage cp ../function_source.zip gs://mtskykhd-tokyo-tf-admin-d06f-function-source/inactive_accounts/function_source.v1.zip
    cd ../
    ```

-----

### フェーズ5：`inactive_accounts`機能の段階的デプロイ

`inactive_accounts`のTerraformコードを、依存関係を解決しながら3段階に分けて`apply`します。

1.  **ステップA：Cloud FunctionとSchedulerの作成**
    a. `inactive_accounts/main.tf` を開き、`google_bigquery_table.inactive_users_view` と `google_monitoring_alert_policy.inactive_account_alert` の2つのリソースを**コメントアウト**します。
    b. `inactive_accounts` ディレクトリで `terraform apply` を実行します。

    > **結果:** Cloud FunctionとCloud Schedulerが作成されます。

2.  **ステップB：BigQuery Viewの作成**
    a. **管理アクティビティログを生成**します。（例：コンソールでいずれかのプロジェクトのラベルを編集・保存、または一時的なGCSバケットを作成・削除する）
    b. **5分ほど待機**し、ログが`logsink`プロジェクトのBigQueryに転送され、`cloudaudit_googleapis_com_activity`テーブルが作成されるのを待ちます。
    c. `inactive_accounts/main.tf` を開き、`resource "google_bigquery_table" "inactive_users_view"` の**コメントアウトを解除**します。
    d. `inactive_accounts` ディレクトリで `terraform apply` を再度実行します。

    > **結果:** BigQuery Viewが作成されます。

3.  **ステップC：アラートポリシーの作成**
    a. コンソールから作成済みの`inactive-account-reporter`関数を**手動で一度実行**します。これによりカスタム指標がCloud Monitoringに登録されます。
    b. `inactive_accounts/main.tf` を開き、`resource "google_monitoring_alert_policy" "inactive_account_alert"` の**コメントアウトを解除**します。
    c. `inactive_accounts` ディレクトリで `terraform apply` を再度実行します。

    > **結果:** アラートポリシーが作成され、すべてのリソースのデプロイが完了します。

### notifications.csvで一つでもTRUEになっている通知先にアラートが通知される事について
はい、2つのアラートで設定方法が違う仕様についてですね。これは、監視する対象の**重要度**と**性質**に基づいて、意図的に設計されたものだと考えられます。

結論から言うと、これは**柔軟性と確実性のバランスを取った、優れた設計パターン**だと思います。

---
## ## ログ一致アラート（CSV方式）の設計思想

CSVで管理するログ一致アラートは、**「運用上発生しうる、多数の様々な種類のアラート」**を想定しています。

* **メリット（なぜこの方式か？）**
    * **柔軟な通知先設定:** アラートの種類ごとに、担当チームや担当者（例えば、あるアラートはAチーム、別のアラートはBチーム）に通知を振り分けることができます。これにより、不要な通知による「アラート疲れ」を防ぎます。
    * **拡張性:** 将来、監視したいログの種類が10個、20個と増えても、CSVファイルに行を追加していくだけで簡単かつ体系的に管理できます。
    * **管理の容易さ:** Terraformのコードを直接触ることなく、CSVファイルの`TRUE`/`FALSE`を書き換えるだけで、誰がどの通知を受け取るかを簡単に変更できます。

この方式は、まるで**ニュースレターの購読**に似ています。読者は自分の興味のあるトピック（アラート）だけを選んで購読できます。

---
## ## `inactive_account_alert`の設計思想

一方、今回実装した`inactive_account_alert`は、**「組織全体のセキュリティに関わる、極めて重要度の高いアラート」**として設計されています。

* **メリット（なぜこの方式か？）**
    * **確実な通知:** このアラートは非常に重要なので、「担当者がCSVに登録し忘れた」といったヒューマンエラーで通知が届かない事態を絶対に避けたいです。そのため、通知先リスト（`notifications.csv`に`TRUE`が一つでもある人）に登録されている**全員に、強制的に通知する**仕様になっています。
    * **シンプルさ:** Terraformのコードは「存在するすべての通知チャネルに送る」というシンプルなロジックになり、設定ミスが起こる可能性が低くなります。

この方式は、**火災報知器**に似ています。火事の疑いがある時に「誰が通知を受け取りますか？」とは聞かず、建物にいる全員に危険を知らせます。

---
## ## 結論：なぜ仕様が違うのか

2つの仕様の違いは、扱うアラートの性質の違いに基づいた、意図的な設計です。

| 比較項目 | ログ一致アラート（CSV方式） | inactive\_account\_alert |
| :--- | :--- | :--- |
| **目的** | 柔軟な通知の振り分け | 確実な一斉通知 |
| **想定アラート** | 多数の運用アラート | 少数の最重要セキュリティアラート |
| **設定単位** | アラートごと | 通知システム全体 |
| **例えるなら** | ニュースレター購読 | 火災報知器 |

このように、アラートの重要性に応じて通知の仕組みを変えるのは、大規模なシステムを運用する上で非常に堅牢で合理的なアプローチです。