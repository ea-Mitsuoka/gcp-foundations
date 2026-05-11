#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# GCP Foundations - Global Destruction Script (Auto-Unlock Enabled)
# ------------------------------------------------------------------------------

ROOT_DIR="$(git rev-parse --show-toplevel)"
export PATH="${ROOT_DIR}/terraform/scripts:$PATH"
export TF_IN_AUTOMATION="true"  # ★この1行を追加

INCLUDE_BASE=false
FROM_LAYER=${LAYER:-1}

for arg in "$@"; do
  if [[ "$arg" == "ALL" ]]; then
    INCLUDE_BASE=true
  fi
done

# 破壊許可フラグの確認
ALLOW_DESTROY=$(grep "allow_resource_destruction" "${ROOT_DIR}/terraform/common.tfvars" | cut -d'=' -f2 | tr -d ' "')

if [ "$ALLOW_DESTROY" != "true" ]; then
  echo "❌ ERROR: allow_resource_destruction is NOT set to true in common.tfvars."
  echo "To proceed with destruction, please set 'allow_resource_destruction = true' and run again."
  exit 1
fi

echo "⚠️  WARNING: This will destroy GCP resources managed by this repository."
if [ "$INCLUDE_BASE" = true ]; then
  echo "🔥 MODE: ALL (Layer ${FROM_LAYER}+, Including management projects like logsink, monitoring, and vpc-host)"
else
  echo "🛡️  MODE: STANDARD (Layer ${FROM_LAYER}+, Excluding management projects)"
fi
echo "----------------------------------------------------------"
read -r -p "Are you sure you want to proceed? (type 'DESTROY' to confirm): " confirm
if [[ "$confirm" != "DESTROY" ]]; then
    echo "Aborted."
    exit 1
fi

# L4 プロジェクトを動的に検出
PROJECT_DIRS=()
for proj_dir in "${ROOT_DIR}/terraform/4_projects"/*/; do
  if [ -d "$proj_dir" ]; then
    proj_name="$(basename "$proj_dir")"
    if [ "$proj_name" != "template" ] && [ -f "${proj_dir}terraform.tfvars" ]; then
      PROJECT_DIRS+=("terraform/4_projects/${proj_name}")
    fi
  fi
done

# 削除対象リストの動的構築
DESTROY_TARGETS=()

if [ "$FROM_LAYER" -le 4 ]; then
  DESTROY_TARGETS+=("${PROJECT_DIRS[@]}")
fi

if [ "$FROM_LAYER" -le 3 ]; then
  DESTROY_TARGETS+=("terraform/3_folders")
fi

if [ "$FROM_LAYER" -le 2 ]; then
  DESTROY_TARGETS+=("terraform/2_organization")
fi

if [ "$FROM_LAYER" -le 1 ]; then
  DESTROY_TARGETS+=(
    "terraform/1_core/services/vpc-host"
    "terraform/1_core/services/monitoring/2_alert_policies/logsink_log_alerts"
    "terraform/1_core/services/monitoring/1_notification_channels"
    "terraform/1_core/services/monitoring/scoping"
    "terraform/1_core/services/monitoring/iam"
    "terraform/1_core/services/monitoring/google_project_service"
    "terraform/1_core/services/logsink/asset_inventory_bq_export"
    "terraform/1_core/services/logsink/sinks"
    "terraform/1_core/services/logsink/datasets"
    "terraform/1_core/services/logsink/iam"
    "terraform/1_core/services/logsink/google_project_service"
  )
  if [ "$INCLUDE_BASE" = true ]; then
    DESTROY_TARGETS+=(
      "terraform/1_core/base/vpc-host"
      "terraform/1_core/base/monitoring"
      "terraform/1_core/base/logsink"
    )
  fi
fi

for dir in "${DESTROY_TARGETS[@]}"; do
  # [TEST MODE] logsinkとmonitoringのスキップ制御
  if [[ "$SKIP_MANAGEMENT_PROJECTS" == "true" ]] && [[ "$dir" == *"logsink"* || "$dir" == *"monitoring"* ]]; then
    echo "⏭️ Skipping ${dir} (SKIP_MANAGEMENT_PROJECTS is true)"
    continue
  fi
  if [ ! -d "${ROOT_DIR}/${dir}" ]; then
    continue
  fi

  echo ">>> Processing: ${dir}"
  cd "${ROOT_DIR}/${dir}"
  
  # 初期化
  terraform init -backend-config="${ROOT_DIR}/terraform/common.tfbackend" -reconfigure > /dev/null

  TFVARS_ARGS=()
  if [ -f "terraform.tfvars" ]; then
    TFVARS_ARGS+=("-var-file=terraform.tfvars")
  fi

  # 自動ロック解除 (Apply)
  echo "    🔓 1/2: Unlocking resources (Applying DELETE policy)..."
  terraform apply -var-file="${ROOT_DIR}/terraform/common.tfvars" "${TFVARS_ARGS[@]}" -auto-approve > /dev/null

  # 削除実行 (Destroy)
  echo "    💥 2/2: Destroying resources..."
  terraform destroy -var-file="${ROOT_DIR}/terraform/common.tfvars" "${TFVARS_ARGS[@]}" -auto-approve
  
  echo "----------------------------------------------------------"
done

echo "🎉 Destruction process completed."
