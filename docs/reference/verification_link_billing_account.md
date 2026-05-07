# サービスアカウントによる課金アカウントリンクの検証ログ整理

## 1. 前提

- **課金アカウントをプロジェクトにリンク**する操作を検証。
- `gcloud billing projects link` コマンドを利用。
- サービスアカウント（SA）で実行できるかを試したが苦戦。
- サービスアカウントはプロジェクトに対するオーナー権限を保有している。

______________________________________________________________________

## 2. 組織管理者ユーザーアカウントでの挙動

### 権限がない場合

`roles/billing.admin` 権限が無いと以下のコマンドが通らない：

```shell
gcloud beta billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
  --member=user:$(gcloud config get-value account) \
  --role=roles/billing.admin
```

### 組織レベルで課金アカウント管理者を付与した場合

- `gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT_ID}`\
  → **成功（OK）**

### 組織レベルの課金アカウント管理者を削除した場合

1. まず課金アカウント管理者がある状態で以下のコマンドを実行：
   ```shell
   gcloud beta billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
     --member=user:$(gcloud config get-value account) \
     --role=roles/billing.admin
   ```
1. 組織レベルの課金アカウント管理者を削除。
1. `gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT_ID}`\
   → **成功（OK）**

### 組織レベルの課金アカウント管理者を削除した後の挙動

なぜか以下コマンドで削除が可能：

```shell
gcloud beta billing accounts remove-iam-policy-binding ${BILLING_ACCOUNT_ID} \
  --member=user:$(gcloud config get-value account) \
  --role=roles/billing.admin
```

______________________________________________________________________

## 3. サービスアカウントでの挙動

### 組織レベルで課金アカウント管理者を付与した場合

- `gcloud billing projects link`\
  → **失敗（NG、PERMISSIONエラー）**
- Cloud Billing API を有効化しても、`roles/serviceusage.admin` を付与しても、プロジェクトに対してService Usage 管理者の権限を付与しても効果なし。

### 課金アカウントにサービスアカウントを紐付けした場合

以下を実行：

```shell
gcloud beta billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
  --member=serviceAccount:${SA_EMAIL} \
  --role=roles/billing.admin
  
gcloud billing projects link ${PROJECT_ID} \
  --billing-account=${BILLING_ACCOUNT_ID} \
  --impersonate-service-account=${SA_EMAIL}
```

→ **失敗（NG、PERMISSIONエラー）**

- Cloud Billing API を有効化しても、`roles/serviceusage.admin` を付与しても、プロジェクトに対してService Usage 管理者の権限を付与しても効果なし。

______________________________________________________________________

## 4. 別のユーザーアカウントの場合

### 1. プロジェクトに権限を付与

プロジェクトに対して、`roles/resourcemanager.projectAdmin` または `roles/owner` を付与します。

```bash
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=user:${USER_EMAIL} \
  --role=roles/resourcemanager.projectAdmin
```

### 2. 課金アカウントに権限を付与

課金アカウントに対して、`roles/billing.admin` を付与します。
（付与するアカウントに組織レベルの請求先アカウント管理者権限が必要）

```bash
gcloud beta billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
  --member=user:${USER_EMAIL} \
  --role=roles/billing.admin
```

- `gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT_ID}`\
  → **成功（OK）**

______________________________________________________________________

## 5. まとめ

- **組織管理者アカウントの場合**：
  - 組織レベルで請求先アカウント管理者の権限があれば、`add-iam-policy-binding` は不要。
  - `gcloud billing projects link` が可能。
- **サービスアカウントの場合**：
  - 組織レベルで課金アカウント管理者権限を付与しても、課金アカウントにサービスアカウントを紐付けしても `gcloud billing projects link` が実行できなかった。
  - **原因は不明**。
- **ユーザーアカウントの場合**：
  - プロジェクトに対するオーナー権限と課金アカウントに対する請求先アカウント管理者権限があれば、`gcloud billing projects link` が可能。

______________________________________________________________________

## 6. 結論

以下の2パターンが考えられる。

- **組織管理者の権限でプロジェクトに対して課金アカウントをリンクさせる場合**
  - 組織管理者に対して組織レベルで請求先アカウント管理者を付与。
- **組織管理者以外のユーザーの権限でプロジェクトに対して課金アカウントをリンクさせる場合**
  - プロジェクトに対して組織管理者以外のユーザーにオーナー権限を付与。
  - 組織管理者に対して組織レベルで請求先アカウント管理者を付与（下記の前提条件）。
  - 課金アカウントに対して組織管理者以外のユーザーに請求先アカウント管理者権限を付与。

> **💡 運用上のベストプラクティス**
> 結局いずれの方法も組織レベルで請求先アカウント管理者の権限が必要なため、基本的には組織管理者が課金アカウントをリンクさせれば良いです。ただし、ベストプラクティスでは、組織管理者と課金アカウント管理者を別の人（例えば財務部門のGoogle グループ）にして、さらにプロジェクトに課金アカウントをリンクさせる人をまた別の人に分離して管理します。

______________________________________________________________________

### 7. Appendix. 組織管理者と請求先アカウント管理者の役割分担の例

以下は、役割を分離した具体的な例です：

- **組織管理者**（`roles/resourcemanager.organizationAdmin`）
  - **担当者**: IT管理者やクラウドアーキテクト
  - **役割**: 組織ポリシーの設定、プロジェクト/フォルダの管理、IAMポリシーの全体管理
- **請求先アカウント管理者**（`roles/billing.admin`）
  - **担当者**: 財務チームや経理担当者
  - **役割**: 請求先アカウントの管理、支払い情報の更新、プロジェクトへのリンク設定
- **プロジェクト管理者**（`roles/resourcemanager.projectAdmin`）
  - **担当者**: プロジェクトオーナーや開発チームリーダー
  - **役割**: 特定のプロジェクト内でのリソース管理、請求先アカウントのリンク（`roles/billing.admin`と組み合わせる場合）
