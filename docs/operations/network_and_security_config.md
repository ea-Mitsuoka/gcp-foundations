# ネットワークとセキュリティの詳細設定 (Shared VPC & VPC-SC)

本基盤では、Shared VPC のサブネット構造や VPC Service Controls (VPC-SC) の境界・アクセスレベルの詳細を `gcp_foundations.xlsx` で管理します。

______________________________________________________________________

## 1. Shared VPC のサブネット管理

Shared VPC ホストプロジェクト内に作成するサブネットは、`shared_vpc_subnets` シートで定義します。

| カラム名 | 説明 | 例 |
| :--- | :--- | :--- |
| `host_project_env` | どのホスト環境（`prod` / `dev`）に作成するかを指定します。 | `prod` |
| `subnet_name` | 作成するサブネットの名前です。 | `prd-subnet-01` |
| `region` | サブネットを作成するリージョンを指定します。 | `asia-northeast1` |
| `ip_cidr_range` | サブネットの IP 範囲を指定します。 | `10.0.1.0/24` |

設定後、`make generate` を実行すると `terraform/1_core/base/vpc-host/auto_subnets.tf` が生成されます。

______________________________________________________________________

## 2. VPC Service Controls (VPC-SC) の管理

VPC-SC の詳細設定は以下の 2 つのシートで行います。

### 2.1 サービス境界の定義 (`vpc_sc_perimeters`)

| カラム名 | 説明 | 例 |
| :--- | :--- | :--- |
| `perimeter_name` | 境界の一意識別子です。 | `default_perimeter` |
| `title` | 表示名です。 | `Default Security Perimeter` |
| `restricted_services` | 保護対象とする API サービスをカンマ区切りで指定します。 | `storage.googleapis.com, bigquery.googleapis.com` |

### 2.2 アクセスレベルの定義 (`vpc_sc_access_levels`)

境界内にアクセスできるホワイトリストを定義します。

| カラム名 | 説明 | 例 |
| :--- | :--- | :--- |
| `access_level_name` | アクセスレベルの名前です。 | `office_ip_only` |
| `ip_subnetworks` | 許可する IP 範囲をカンマ区切りで指定します。 | `1.2.3.4/32` |
| `members` | 許可するユーザーやサービスアカウントをカンマ区切りで指定します。 | `user:admin@example.com` |

設定後、`make generate` を実行すると `terraform/2_organization/auto_vpc_sc.tf` が生成されます。

## 3. 組織ポリシー (Organization Policy) の管理

本基盤では、組織全体のガードレールとなる組織ポリシーを `gcp_foundations.xlsx` で管理します。

### 3.1 段階的な適用 (Migration Friendly)

既存のプロジェクトを組織へ移行する場合など、初期状態でポリシーが適用されていると移行がブロックされることがあります。そのため、本基盤ではグローバルな有効化スイッチを備えています。

1.  **`terraform/common.tfvars` の `enable_org_policies`**:
    -   `false` (デフォルト): 組織ポリシーは一切適用されません。移行作業時に推奨されます。
    -   `true`: Excel で定義されたポリシーが有効化されます。

### 3.2 サービスポリシーの定義 (`org_policies`)

適用したいルールを `org_policies` シートで定義します。

| カラム名 | 説明 | 例 |
| :--- | :--- | :--- |
| **target_name** | 適用先（`organization_id`, フォルダ名, プロジェクト名） | `shared`, `organization_id` |
| **policy_id** | ポリシーの名前（ID） | `compute.disableExternalIPProxy` |
| **enforce** | 強制するかどうか (`TRUE` / `FALSE`) | `TRUE` |
| **allow_list** | 許可値のリスト（カンマ区切り。ロケーション制限等で使用） | `asia-northeast1` |

設定後、`make generate` を実行すると、各レイヤーに `auto_org_policies.tf` が生成されます。

______________________________________________________________________

## 4. プロジェクトへの紐付け

`resources` シートの各プロジェクトの行で、上記で定義した名前を指定することで適用されます。

- **`shared_vpc` 列**: 使用する `subnet_name` を入力します。
- **`vpc_sc` 列**: 所属させる `perimeter_name` を入力します。

______________________________________________________________________

## 4. 反映手順

1. `gcp_foundations.xlsx` を編集し、保存します。
2. コマンドを実行して定義ファイルを更新します：
   ```bash
   make generate
   ```
3. 変更内容を反映します：
   ```bash
   make deploy
   ```
