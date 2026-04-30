#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# GCP Foundations - Global Deployment Script
# ------------------------------------------------------------------------------

ROOT_DIR="$(git rev-parse --show-toplevel)"
export PATH="${ROOT_DIR}/terraform/scripts:$PATH"
STATE_FILE="${ROOT_DIR}/.deploy_state"

RESUME=false
PLAN_ONLY=false

for arg in "$@"; do
  if [[ "$arg" == "--resume" ]]; then
    RESUME=true
  elif [[ "$arg" == "--plan-only" ]]; then
    PLAN_ONLY=true
  fi
done

if [[ "$RESUME" == "false" && "$PLAN_ONLY" == "false" ]] && [[ -f "$STATE_FILE" ]] && [[ -t 0 ]]; then
  read -r -p "A previous deployment state was found. Do you want to resume from the last successful layer? (y/N): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    RESUME=true
  fi
fi

if [[ "$RESUME" == "false" ]]; then
  echo "Starting fresh deployment. Clearing previous state..."
  rm -f "$STATE_FILE"
  touch "$STATE_FILE"
else
  echo "Resuming deployment based on state file..."
fi

echo "=========================================================="
echo " Step 0: Pre-flight Check"
echo "=========================================================="
bash "${ROOT_DIR}/terraform/scripts/preflight_check.sh"

echo ""
echo "=========================================================="
echo " Step 1: Generating tfvars from SSoT (domain.env & xlsx)"
echo "=========================================================="

if ! command -v uv &> /dev/null; then
    echo "Error: 'uv' is not installed. Please install it first."
    echo "Run: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# uv run を使うことで、requirements.txtやvenvの管理なしにクリーンに実行可能
uv run "${ROOT_DIR}/terraform/scripts/generate_resources.py"


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
    if [ "$proj_name" != "template" ]; then
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

  # レジューム（再開）が有効な場合、既に成功したディレクトリはスキップする
  if [[ "$RESUME" == "true" ]] && grep -Fxq "$dir" "$STATE_FILE"; then
    echo "⏭️ Skipping ${dir} (Already deployed successfully in previous run)"
    continue
  fi
  
  # 課金が未リンクの場合、API有効化を伴う services ディレクトリを安全にスキップ
  if [ "$CORE_BILLING_LINKED" != "true" ] && [[ "$dir" == *"1_core/services"* ]]; then
    echo "⏭️ Skipping ${dir} (core_billing_linked is false. Please link billing accounts and set it to true)"
    continue
  fi

  echo ">>> Deploying: ${dir}"
  cd "${ROOT_DIR}/${dir}"
  
  # CI環境などで認証情報がない場合、バックエンドをスキップして検証を継続できるようにする
  INIT_ARGS=("-backend-config=${ROOT_DIR}/terraform/common.tfbackend" "-reconfigure")
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q . && [[ "${TF_IN_AUTOMATION}" == "true" ]]; then
    echo "⚠️ No GCP credentials found. Initializing with -backend=false"
    INIT_ARGS=("-backend=false" "-reconfigure" "-backend-config=bucket=dummy-bucket")
  fi

  terraform init "${INIT_ARGS[@]}"
  
  # terraform.tfvarsが存在する場合のみ読み込むためのハンドリング
  TFVARS_ARGS=()
  if [ -f "terraform.tfvars" ]; then
    TFVARS_ARGS+=("-var-file=terraform.tfvars")
  fi
  
  # エラー発生時はここでスクリプトが停止し、状態ファイルには未記録となる
  # 認証情報がない場合は plan もエラーになるため、CIかつ認証なしの場合は検証(validate)のみに留める
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q . && [[ "${TF_IN_AUTOMATION}" == "true" ]]; then
    echo "⏭️ No GCP credentials found. Running terraform validate instead of plan."
    terraform validate
  else
    terraform plan -var-file="${ROOT_DIR}/terraform/common.tfvars" "${TFVARS_ARGS[@]}" -out=tfplan
    
    if [[ "$PLAN_ONLY" == "false" ]]; then
      terraform apply -auto-approve tfplan
      
      # 成功したら状態ファイルに記録
      echo "$dir" >> "$STATE_FILE"
    else
      echo "⏭️ Plan only mode. Skipping apply."
    fi
  fi
  
  echo "----------------------------------------------------------"
done

if [[ "$PLAN_ONLY" == "false" ]]; then
  echo ""
  echo "=========================================================="
  echo " 🎉 All deployments completed successfully!"
  echo "=========================================================="
  echo " Next Steps:"
  echo " - [Verify]   Log in to the GCP Console and check your resources."
  echo " - [Operate]  To add/modify projects, update the spreadsheet and run 'make generate' again."
  echo " - [Guide]    Refer to 'docs/operations/project_lifecycle.md' for daily operations."
  echo "=========================================================="
  # 全て成功した場合は状態ファイルを削除
  rm -f "$STATE_FILE"
else
  echo ""
  echo "=========================================================="
  echo " 🎉 All plans completed successfully!"
  echo "=========================================================="
  echo " Review the plans above and run 'make deploy' to apply changes."
  echo "=========================================================="
fi
