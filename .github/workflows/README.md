# Terraform CI ワークフロー設計メモ

このディレクトリの `lint.yml` は、Terraform の品質を「PR前に自動で落とせる」ことを最優先に設計しています。

## 目的

- フォーマット不一致を自動検出する（`terraform fmt -check -recursive`）
- 静的解析で潜在的な問題を早期に検出する（`tflint --recursive`）
- Terraform ルートモジュールの構文整合性を一括検証する（`terraform validate`）

## 設計思想

- 品質ゲートは厳格にする
  - `tflint` は `--force` を使わず、違反時はジョブを失敗させる
  - `continue-on-error` は使わず、異常をそのままCI失敗として扱う
- ルートモジュール列挙を自動化する
  - 手動の matrix 管理は漏れやメンテ負荷が高いため、`discover` ジョブで自動生成
  - `terraform/modules`（再利用モジュール群）と `*/.terraform/*`（作業生成物）は検証対象から除外
- 依存環境に左右されない validate を優先する
  - `terraform init -backend=false` を使い、CI上で backend の実値（例: GCS bucket）がなくても `validate` を実行可能にする

## 特殊事情（このリポジトリ前提）

- 多くのディレクトリで `backend "gcs"` の `bucket` をコードに固定していない
  - 運用時は `terraform init` 引数などで注入する前提
  - そのため、CIで通常の `terraform init` を使うと backend 初期化で失敗しやすい
- Terraform ルートが階層的に増減する構成
  - ルート追加時に workflow 側を毎回編集しなくても、`discover` が自動追従する

## 運用メモ

- 新しい Terraform ルートを追加した場合、通常は `lint.yml` の修正は不要
- 例外的に validate 対象から外したいディレクトリがある場合のみ、`discover` の除外条件を更新する
