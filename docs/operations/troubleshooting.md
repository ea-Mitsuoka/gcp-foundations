# トラブルシューティング・ガイド (Troubleshooting Guide)

本ドキュメントでは、GCP Foundations の構築および運用中に発生しがちな問題とその解決策をまとめています。

______________________________________________________________________

## 1. セットアップ・構築時の問題

### 1.1 `make setup` (setup_new_client.sh) が失敗する

#### 症状: 「Could not find Organization ID for domain...」というエラー

- **原因**: 入力したドメイン名が間違っているか、実行ユーザーに組織レベルの閲覧権限（`roles/resourcemanager.organizationViewer`）が不足しています。
- **対策**: `gcloud organizations list` を手動で実行して組織が表示されるか確認してください。

#### 症状: 請求先アカウントのリンクで止まる

- **原因**: スクリプトが指示する「手動での請求先アカウント紐づけ」が完了していません。
- **対策**: 画面に表示された `gcloud billing projects link ...` コマンドを別のターミナルで実行してから、[Enter] を押してください。

### 1.2 予算アラート・課金アカウント紐付けのエラー

#### 症状: 予算作成時に「Error 404: Requested entity was not found.」というエラー

- **原因**: `make setup` 時にテスト用のダミー値（`dummy`）を指定したままになっているため、実在しない課金アカウントとして拒否されています。
- **対策**: `gcloud billing accounts list` で実際のACCOUNT_IDを取得し、`common.tfvars` の値を本物に書き換えてから再実行してください。

### 1.3 API の有効化エラー

#### 症状: `terraform apply` 中に「API [service] not enabled」というエラー

- **原因**: プロジェクトで必要な API が有効になっていません。
- **対策**:
  - **管理プロジェクト (Core/Org等) の場合**: `terraform/1_core/services/...` 配下の `variables.tf` 等に必要な API が記載されているか確認してください。
  - **アプリケーションプロジェクト (L4) の場合**: 本基盤は L4 プロジェクトの API 有効化を管理していません。現場の IaC または手動で API を有効化してください。

#### 症状: 共有プロジェクトで「Cloud Pub/Sub API (または Cloud Asset API) has not been used in project [管理プロジェクト番号]」という 403 エラーが出る

- **原因**: Pub/Sub スキーマや組織アセットフィードなどの一部のリソースは、操作対象プロジェクトだけでなく、操作を実行する「管理（tfstate）プロジェクト」側でも API が有効になっている必要があります。
- **対策**:
  1. 管理プロジェクトで API を手動有効化します：`gcloud services enable pubsub.googleapis.com cloudasset.googleapis.com --project=[管理プロジェクトID]`
  1. または、`terraform/0_bootstrap/google_project_service/variables.tf` の `project_apis` にこれらを追記して `apply` してください。
  1. また、`provider.tf` で `user_project_override = true` を設定して、ターゲットプロジェクトのクォータを使用するようにします。

#### 症状: プロジェクト作成直後に「Billing account for project '...' is not found.」というエラー

- **原因**: L1 などの管理プロジェクトにおいて、課金アカウントのリンク前に API を有効化しようとしています。
- **対策**:
  - プロジェクト作成後、管理者が手動で課金アカウントをリンクしてから再度 `make deploy` を実行してください。

______________________________________________________________________

## 2. Google グループ・IAM 関連の問題

### 2.1 Google グループが見つからない

#### 症状: `terraform apply` 中に「Group [group-name] not found」というエラー

- **原因**: Cloud Identity / Google Workspace 上でグループが作成されていないか、ドメイン名が `common.tfvars` の定義と一致していません。
- **対策**:
  - [Google グループ作成ガイド](../setup/google_groups_creation.md) に従ってグループを作成してください。
  - `domain.env` または `terraform/common.tfvars` の `organization_domain` が正しいか確認してください。

### 2.2 Cloud セットアップとの競合

#### 症状: Cloud セットアップを最後まで進めてしまい、Terraform と権限の奪い合いが発生する

- **原因**: Cloud セットアップが自動付与した IAM 権限と、Terraform が管理する IAM 権限が重複・競合しています。
- **対策**: コンソールの IAM 画面から、Cloud セットアップによって直接付与された古い権限を削除し、Terraform 側で一元管理するようにしてください。

______________________________________________________________________

## 3. Excel (SSoT) 関連の問題

### 3.1 `make generate` が期待通りに動かない

#### 症状: Excel を更新したのに `.tf` ファイルが更新されない

- **原因**: Excel ファイルを保存していないか、シート名・カラム名を変更してしまっています。
- **対策**: Excel を保存し、シート名（`resources`, `org_policies` 等）が正しいか確認してください。

#### 症状: セル内の「True / False」が反映されない

- **原因**: 文字列として "True" と入力されているか、セルの書式が特殊です。
- **対策**: `generate_resources.py` は大文字小文字を区別せず "true" を判別しますが、基本的には論理値として入力してください。

______________________________________________________________________

## 5. ドリフト検知 (Drift Detection)

### 5.1 定期チェックの失敗

#### 症状: GitHub Actions の `Infrastructure Drift Detection` がエラーになっている

- **原因**: 誰かがコンソール等で直接設定を変更した（ドリフト）、または Terraform コードの修正が反映されていません。
- **対策**: Actions のログを確認し、`plan` の差異を確認してください。意図した変更であればコードを更新し、意図しないものであればコンソールから差し戻してください。

> **TODO (今後の改善)**:
> 現在は GitHub Actions のログ上でのみ通知されますが、運用を効率化するために Slack への通知連携や、Drift 検知時の GitHub Issue 自動作成の導入を検討してください。
