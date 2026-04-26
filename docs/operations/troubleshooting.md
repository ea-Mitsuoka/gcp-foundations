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

### 1.2 API の有効化エラー

#### 症状: `terraform apply` 中に「API [service] not enabled」というエラー
- **原因**: プロジェクトで必要な API が有効になっていません。
- **対策**: Excel (SSOT) の `project_apis` 列に必要な API が記載されているか確認し、`make generate` を実行した後に再度 `apply` してください。または、課金アカウントが正しくリンクされているか確認してください。

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

## 3. Excel (SSOT) 関連の問題

### 3.1 `make generate` が期待通りに動かない

#### 症状: Excel を更新したのに `.tf` ファイルが更新されない
- **原因**: Excel ファイルを保存していないか、シート名・カラム名を変更してしまっています。
- **対策**: Excel を保存し、シート名（`resources`, `org_policies` 等）が正しいか確認してください。

#### 症状: セル内の「True / False」が反映されない
- **原因**: 文字列として "True" と入力されているか、セルの書式が特殊です。
- **対策**: `generate_resources.py` は大文字小文字を区別せず "true" を判別しますが、基本的には論理値として入力してください。

______________________________________________________________________

## 4. その他

### 4.1 Terraform の State ロック
- **症状**: 「Error: Error acquiring the state lock」
- **原因**: 別の担当者がデプロイ中であるか、前回のデプロイが異常終了してロックが解除されていません。
- **対策**: 誰も実行していないことが確実な場合は、`terraform force-unlock <LOCK_ID>` を実行してください。
