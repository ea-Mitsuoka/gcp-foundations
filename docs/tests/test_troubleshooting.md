# テスト実行時トラブルシューティング・ガイド (Test Troubleshooting)

本ドキュメントは、GCP Foundations 基盤のテスト実行中（および今後の実運用中）に発生したエラーと、その具体的な解決手順を記録したナレッジベースです。
エラーに遭遇した場合は、まず本ドキュメントの表から類似の症状を探し、記載されている解決策を試してください。

______________________________________________________________________

## エラー解決ログ

| 発生フェーズ | エラーメッセージ / 症状 | 原因 | 解決策 (実行コマンド) | 備考 |
| :--- | :--- | :--- | :--- | :--- |
| `make deploy`<br>`make destroy` | `oauth2: "invalid_grant" "reauth related error (invalid_rapt)"` | Terraformが裏側で使用している「Application Default Credentials (ADC)」の認証トークンの有効期限が切れた（またはGoogle Workspaceのセッション再認証要求に引っかかった）ため。 | ターミナルで以下の2つのコマンドを実行し、ブラウザで再認証を行う。<br><br>`gcloud auth login`<br>`gcloud auth application-default login` | Pre-flight checkが通過（表面的なgcloud認証は有効）していても、Terraform用のAPIトークン(ADC)が切れていると発生する。長時間の作業時に遭遇しやすい。 |
| `make deploy` | `Error creating MonitoredProject: googleapi: Error 403: The caller does not have permission` <br>*(※20分近く `Still creating...` で固まった後に発生)* | GCPの Cloud Monitoring API (`google_monitoring_monitored_project`) の処理遅延バグ。Terraformが完了を待ち続ける間に、裏側の認証トークン（ADC）の寿命（1時間）が切れて強制終了している。 | 一旦対象ディレクトリの `main.tf` を `main.tf.bak` にリネームして無力化し、`make deploy` (Resume: `y`) で該当レイヤーをスキップさせる。 | GCP側のAPI仕様/遅延に起因するため、Terraform側からの根本解決が難しい既知の罠。L1の監視連携部分なので、スキップしてもL3/L4リソースの構築テストには影響しない。(例:`mv terraform/1_core/services/monitoring/scoping/main.tf terraform/1_core/services/monitoring/scoping/main.tf.bak`, `mv terraform/1_core/services/monitoring/scoping/outputs.tf terraform/1_core/services/monitoring/scoping/outputs.tf.bak`) |
| `make deploy` | `Error 400: field [parent] has issue [Parent id must be numeric.]` | プロジェクト作成時、親（フォルダまたは組織）のIDとして数字のみが要求される箇所に対し、`"organizations/123456789"` のような文字列が渡された、もしくは自動生成の残骸（文字列）が残っていたため。 | 1. 過去のテストディレクトリの残骸を手動で削除する（`rm -rf terraform/4_projects/不要なディレクトリ`）。<br>2. Terraformモジュール側 (`project-factory/main.tf`) で `replace(var.organization_id, "organizations/", "")` のように不要な文字列を取り除く処理を追加し、堅牢化する。 | Terraformの `data.google_organization` が返すIDには `"organizations/"` が付与される仕様があり、APIの要求する純粋な数値フォーマットとズレることで発生するGCP Terraformあるあるの罠。 |
