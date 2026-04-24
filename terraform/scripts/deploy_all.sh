#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# GCP Foundations - Global Deployment Script
# ------------------------------------------------------------------------------

ROOT_DIR="$(git rev-parse --show-toplevel)"
export PATH="${ROOT_DIR}/terraform/scripts:$PATH"

echo "=========================================================="
echo " Step 1: Generating tfvars from SSOT (domain.env & xlsx)"
echo "=========================================================="

if ! command -v uv &> /dev/null; then
    echo "Error: 'uv' is not installed. Please install it first."
    echo "Run: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# uv run を使うことで、requirements.txtやvenvの管理なしにクリーンに実行可能
uv run "${ROOT_DIR}/terraform/scripts/generate_tfvars.py"

echo ""
echo "=========================================================="
echo " Step 2: Deploying Terraform layers in dependency order"
echo "=========================================================="

# 依存関係に配慮したデプロイ順序の定義
TARGET_DIRS=(
  "terraform/1_core/base/logsink"
  "terraform/1_core/base/monitoring"
  "terraform/1_core/services/logsink/google_project_service"
  "terraform/1_core/services/logsink/iam"
  "terraform/1_core/services/logsink/datasets"
  "terraform/1_core/services/logsink/sinks"
  "terraform/1_core/services/logsink/asset_inventory_bq_export"
  "terraform/1_core/services/monitoring/google_project_service"
  "terraform/1_core/services/monitoring/iam"
  "terraform/1_core/services/monitoring/scoping"
  "terraform/1_core/services/monitoring/1_notification_channels"
  "terraform/1_core/services/monitoring/2_alert_policies/logsink_log_alerts"
  "terraform/2_organization"
  "terraform/3_folders"
  "terraform/1_core/base/vpc-host"
  "terraform/1_core/services/vpc-host"
)

# 4_projects 配下のプロジェクトディレクトリを動的に検出して追加
for proj_dir in "${ROOT_DIR}/terraform/4_projects"/*/; do
  if [ -d "$proj_dir" ]; then
    proj_name="$(basename "$proj_dir")"
    # テンプレートディレクトリはデプロイ対象から除外する
    if [ "$proj_name" != "example_project" ]; then
      TARGET_DIRS+=("terraform/4_projects/${proj_name}")
    fi
  fi
done

# コアプロジェクトの課金リンク状態を取得
CORE_BILLING_LINKED=$(grep "core_billing_linked" "${ROOT_DIR}/terraform/common.tfvars" | cut -d'=' -f2 | tr -d ' "')

for dir in "${TARGET_DIRS[@]}"; do
  if [ ! -d "${ROOT_DIR}/${dir}" ]; then
    echo "Skipping ${dir} (Directory not found)"
    continue
  fi
  
  # 課金が未リンクの場合、API有効化を伴う services ディレクトリを安全にスキップ
  if [ "$CORE_BILLING_LINKED" != "true" ] && [[ "$dir" == *"1_core/services"* ]]; then
    echo "⏭️ Skipping ${dir} (core_billing_linked is false. Please link billing accounts and set it to true)"
    continue
  fi

  echo ">>> Deploying: ${dir}"
  cd "${ROOT_DIR}/${dir}"
  
  terraform init -backend-config="${ROOT_DIR}/terraform/common.tfbackend" -reconfigure
  
  # terraform.tfvarsが存在する場合のみ読み込むためのハンドリング
  TFVARS_ARG=""
  if [ -f "terraform.tfvars" ]; then
    TFVARS_ARG="-var-file=terraform.tfvars"
  fi
  
  terraform plan -var-file="${ROOT_DIR}/terraform/common.tfvars" ${TFVARS_ARG} -out=tfplan
  terraform apply -auto-approve tfplan
  echo "----------------------------------------------------------"
done

echo "🎉 All deployments completed successfully!"
