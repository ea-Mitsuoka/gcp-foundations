# 課金アカウントのリンク設定

## 課金アカウントリンクに必要なIDを取得

```bash
export PROJECT_ID=$(gcloud projects list --filter="name:mtskykhd-tokyo-monitoring" --format="value(projectId)")


export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)

echo $PROJECT_ID
echo $BILLING_ACCOUNT_ID
```

## 課金アカウントをリンク

```bash
gcloud billing projects link ${PROJECT_ID} \
      --billing-account=${BILLING_ACCOUNT_ID}
```
