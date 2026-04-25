# モジュールのメンテナンス手順

本リポジトリで利用されている Terraform モジュール（ローカルおよび外部）を安全に更新するための手順を説明します。

______________________________________________________________________

## 1. ローカルモジュールの更新

`terraform/modules/` 配下に格納されている共通部品を更新する場合の手順です。

### ステップ 1: コードの編集

`terraform/modules/<module-name>/` 内の `.tf` ファイルを編集します。

### ステップ 2: ドキュメントの自動生成

変数 (`variables.tf`) や出力 (`outputs.tf`) を変更した場合は、`terraform-docs` を使用して `README.md` を更新します。

```bash
terraform-docs markdown table --output-file README.md terraform/modules/<module-name>/
```

### ステップ 3: 影響範囲の確認 (Grep & Plan)

そのモジュールを使用している箇所を特定し、`terraform plan` で意図しない破壊的変更がないか確認します。

```bash
grep -r "source.*<module-name>" terraform/
```

______________________________________________________________________

## 2. 外部モジュールの更新

GitHub 等の外部リポジトリから `git::` で参照しているモジュールを更新する場合の手順です。

### ステップ 1: コミットハッシュの取得

外部リポジトリで必要な修正を行い、最新のコミットハッシュ（40文字）を取得します。

### ステップ 2: 参照先 (`ref`) の更新

呼び出し側の `source` 引数にある `ref` パラメータを新しいハッシュに書き換えます。

```hcl
# 修正前
source = "git::https://github.com/example/modules.git//my-module?ref=old-hash"

# 修正後
source = "git::https://github.com/example/modules.git//my-module?ref=new-hash"
```

### ステップ 3: 動作確認

`terraform init -reconfigure` を実行して新しいモジュールソースを取得し、`terraform plan` で影響を確認します。

______________________________________________________________________

## 3. 注意事項

- **破壊的変更**: 変数名の変更や削除は、それを利用している全てのプロジェクトに影響します。可能な限りデフォルト値を設定するか、後方互換性を維持するように設計してください。
- **CI/CD**: プルリクエスト作成時に実行される CI ジョブ（Lint, OPA, Test）が全てパスすることを確認してください。
