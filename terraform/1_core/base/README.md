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

- 2種類あり好きな方を使う
  - domain.com → domain-com-<project_name>

  ```bash
  module "string_utils" {
    source          = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae09b1"
  ```

  - domain.com → dc-<project_name>

  ```bash
  module "string_utils" {
    source          = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=54a758c"
  ```
