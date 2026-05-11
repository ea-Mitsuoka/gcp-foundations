#!/bin/bash
#
# This script automates the initial environment setup for a new client.
# It prioritizes idempotency and safe reuse of existing resources.

print_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
DOMAIN_ENV_PATH="${REPO_ROOT}/domain.env"
COMMON_VARS_PATH="${REPO_ROOT}/terraform/common.tfvars"

# --- Step 0: Prerequisite Checks ---
print_info "Checking prerequisites..."
for cmd in gcloud terraform openssl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        print_error "$cmd CLI not found."
        exit 1
    fi
done
print_success "Prerequisites met."

# --- Step 1: Domain & Billing Input ---
if [ -f "$DOMAIN_ENV_PATH" ]; then
    CUSTOMER_DOMAIN=$(grep -E '^domain=' "$DOMAIN_ENV_PATH" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    print_info "Loaded existing domain: $CUSTOMER_DOMAIN"
else
    read -r -p "Enter customer's domain (e.g., example.com): " CUSTOMER_DOMAIN
    echo "domain=\"${CUSTOMER_DOMAIN}\"" > "$DOMAIN_ENV_PATH"
fi

print_info "Fetching available Billing Accounts..."
gcloud billing accounts list --format="table(name,displayName)" || true
AUTO_BILL_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1 2>/dev/null || true)
read -r -p "Enter Billing Account ID [Default: ${AUTO_BILL_ID:-dummy}]: " BILLING_ACCOUNT_ID
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-$AUTO_BILL_ID}
[[ "$BILLING_ACCOUNT_ID" == "dummy" || -z "$BILLING_ACCOUNT_ID" ]] && BILLING_ACCOUNT_ID="012345-6789AB-CDEF01"

# --- Step 2: Organization ID ---
ORGANIZATION_ID="$(gcloud organizations list --filter="displayName=${CUSTOMER_DOMAIN}" --format="value(ID)")"
if [ -z "$ORGANIZATION_ID" ]; then
    print_error "Could not find Org ID for '$CUSTOMER_DOMAIN'."
    exit 1
fi

# --- Step 3: 🚀 Interactive Project Selection 🚀 ---
print_info "Searching for ACTIVE tfstate projects in your environment..."

# 組織直下という制限を外し、ゴミ箱に入っていない(ACTIVE) tfstateプロジェクトを全検索
PROJECTS_OUTPUT=$(gcloud projects list --filter="lifecycleState=ACTIVE AND (projectId:*tfstate* OR name:*tfstate*)" --format="value(projectId)")

TFSTATE_PROJECTS=()
if [ -n "$PROJECTS_OUTPUT" ]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && TFSTATE_PROJECTS+=("$line")
    done <<< "$PROJECTS_OUTPUT"
fi

MGMT_PROJECT_ID=""
if [ ${#TFSTATE_PROJECTS[@]} -gt 0 ]; then
    print_warning "Existing tfstate project(s) found. Please select which one to reuse:"
    OPTIONS=("${TFSTATE_PROJECTS[@]}" "Create a NEW project")
    PS3="Enter a number: "
    select OPT in "${OPTIONS[@]}"; do
        if [[ "$OPT" == "Create a NEW project" ]]; then
            break
        elif [[ -n "$OPT" ]]; then
            MGMT_PROJECT_ID="$OPT"
            print_success "Selected existing project: $MGMT_PROJECT_ID"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# --- Step 4: Define Variables based on Selection ---
# プレフィックスのデフォルト案を決定
if [ -n "$MGMT_PROJECT_ID" ]; then
    # 後方一致による削除 (${変数%%パターン})
    SUGGESTED_PREFIX="${MGMT_PROJECT_ID%%-tfstate-*}"
else
    SUGGESTED_PREFIX=$(echo "$CUSTOMER_DOMAIN" | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-14)
    # 末尾のハイフン削除 (${変数%-})
    SUGGESTED_PREFIX="${SUGGESTED_PREFIX%-}"
fi

# common.tfvars があれば既存値を優先
if [ -f "$COMMON_VARS_PATH" ]; then
    EXISTING_PREFIX=$(grep "project_id_prefix" "$COMMON_VARS_PATH" | cut -d'=' -f2 | tr -d ' "')
    SUGGESTED_PREFIX=${EXISTING_PREFIX:-$SUGGESTED_PREFIX}
fi

# 既存tfstateを使う場合でも、logsink等のプレフィックスは自由に入力させる
while true; do
    read -r -p "Enter Project ID Prefix for new resources (logsink, etc.) [Default: $SUGGESTED_PREFIX]: " PROJECT_ID_PREFIX
    PROJECT_ID_PREFIX=${PROJECT_ID_PREFIX:-$SUGGESTED_PREFIX}
    if [[ "$PROJECT_ID_PREFIX" =~ ^[a-z][a-z0-9-]{2,13}$ ]] && [[ ! "$PROJECT_ID_PREFIX" =~ -$ ]]; then
        break
    else
        print_error "Invalid prefix (3-14 chars, no trailing hyphen)."
    fi
done

# tfstateプロジェクト関連の変数設定
if [ -n "$MGMT_PROJECT_ID" ]; then
    print_info "Fetching ACTUAL GCS bucket inside ${MGMT_PROJECT_ID}..."
    EXISTING_BUCKET=$(gcloud storage buckets list --project="${MGMT_PROJECT_ID}" --format="value(name)" | grep "tfstate" | head -n 1 || true)
    if [ -n "$EXISTING_BUCKET" ]; then
        GCS_BUCKET_TFSTATE="$EXISTING_BUCKET"
    else
        GCS_BUCKET_TFSTATE="${MGMT_PROJECT_ID}-bucket"
    fi
    # 既存プロジェクトの名前を取得（取得できなければIDをそのまま使う）
    MGMT_PROJECT_NAME=$(gcloud projects describe "${MGMT_PROJECT_ID}" --format="value(name)" 2>/dev/null || echo "${MGMT_PROJECT_ID}")
else
    MGMT_PROJECT_ID="${PROJECT_ID_PREFIX}-tfstate-$(openssl rand -hex 2)"
    GCS_BUCKET_TFSTATE="${MGMT_PROJECT_ID}-bucket"
    MGMT_PROJECT_NAME="${PROJECT_ID_PREFIX}-tfstate"
fi

SA_NAME="terraform-org-manager"
SA_EMAIL="${SA_NAME}@${MGMT_PROJECT_ID}.iam.gserviceaccount.com"

# --- Step 5: Toggles ---
read -r -p "Enter GCP region [Default: asia-northeast1]: " GCP_REGION
GCP_REGION=${GCP_REGION:-asia-northeast1}

get_bool_input() {
    local prompt=$1
    local default=$2
    read -r -p "$prompt (true/false) [Default: $default]: " val
    echo "${val:-$default}" | tr '[:upper:]' '[:lower:]'
}

ENABLE_VPC=$(get_bool_input "Enable Shared VPC?" "false")
ENABLE_VPC_SC=$(get_bool_input "Enable VPC Service Controls?" "false")
ENABLE_ORG_POLICIES=$(get_bool_input "Enable Org Policies?" "false")
ENABLE_TAGS=$(get_bool_input "Enable Org Tags?" "false")
ENABLE_SIMPLIFIED_GROUPS=$(get_bool_input "Enable Simplified Admin Groups?" "false")

# --- Step 6: Confirmation & Execution ---
echo -e "\n--------------------------------------------------"
if gcloud projects describe "${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    echo " 🟢 REUSING EXISTING INFRASTRUCTURE (Mgmt Project)"
else
    echo " 🔵 CREATING NEW INFRASTRUCTURE (Mgmt Project)"
fi
echo "   Org ID:          $ORGANIZATION_ID"
echo "   App Prefix:      $PROJECT_ID_PREFIX (Will be used for logsink, monitoring, etc.)"
echo "   Mgmt Project ID: $MGMT_PROJECT_ID"
echo "   Bucket Name:     gs://$GCS_BUCKET_TFSTATE"
echo "   Service Account: $SA_EMAIL"
echo "--------------------------------------------------"
read -r -p "Proceed? (y/n): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { print_error "Aborted."; exit 1; }

# 1. Project
if ! gcloud projects describe "${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    gcloud projects create "${MGMT_PROJECT_ID}" --name="${MGMT_PROJECT_NAME}" --organization="${ORGANIZATION_ID}"
fi

# 2. Billing
CURRENT_LINK_STATUS="true"
CURRENT_BILLING=$(gcloud billing projects describe "${MGMT_PROJECT_ID}" --format="value(billingAccountName)" 2>/dev/null || true)
if [[ "$CURRENT_BILLING" != *"$BILLING_ACCOUNT_ID" ]]; then
    print_info "Linking billing account automatically..."
    if gcloud billing projects link "${MGMT_PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}" --quiet >/dev/null 2>&1; then
        print_success "Billing account linked successfully."
    else
        print_warning "Failed to link billing account automatically (Dummy ID or insufficient permissions)."
        echo "Please link the billing account manually in another terminal:"
        echo "  gcloud billing projects link \"${MGMT_PROJECT_ID}\" --billing-account=\"YOUR_BILLING_ID\""
        read -r -p "Press [Enter] after linking manually to continue (or press Enter to skip and link later): "
        CURRENT_LINK_STATUS="false"
    fi
fi

# 3. APIs
gcloud services enable cloudresourcemanager.googleapis.com storage.googleapis.com iam.googleapis.com \
    serviceusage.googleapis.com iamcredentials.googleapis.com orgpolicy.googleapis.com \
    logging.googleapis.com pubsub.googleapis.com cloudasset.googleapis.com --project="${MGMT_PROJECT_ID}" --quiet

# 4. GCS Bucket
if ! gcloud storage buckets describe "gs://${GCS_BUCKET_TFSTATE}" --project="${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    gcloud storage buckets create "gs://${GCS_BUCKET_TFSTATE}" --project="${MGMT_PROJECT_ID}" --location="${GCP_REGION}" --uniform-bucket-level-access
    gcloud storage buckets update "gs://${GCS_BUCKET_TFSTATE}" --project="${MGMT_PROJECT_ID}" --versioning
fi

# 5. Service Account
NEW_SA_CREATED=false
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project="${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    gcloud iam service-accounts create "${SA_NAME}" --display-name="Terraform Organization Manager" --project="${MGMT_PROJECT_ID}"
    NEW_SA_CREATED=true
fi

# 6. IAM Permissions
print_info "Syncing IAM permissions..."
if [ "$NEW_SA_CREATED" = true ]; then
    print_info "Waiting for Service Account propagation to Organization IAM..."
    MAX_RETRIES=6
    RETRY_COUNT=0
    while ! gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.organizationViewer" --quiet >/dev/null 2>&1; do
      RETRY_COUNT=$((RETRY_COUNT+1))
      if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        print_error "Failed to apply IAM binding after $MAX_RETRIES attempts."
        exit 1
      fi
      print_warning "SA not yet recognized. Retrying in 10s... ($RETRY_COUNT/$MAX_RETRIES)"
      sleep 10
    done
fi

# --- 💡 リファクタリング：ROLES 配列の整理 ---
ROLES=(
    # --- Resource Manager ---
    "roles/resourcemanager.organizationViewer"
    "roles/resourcemanager.folderAdmin"
    "roles/resourcemanager.projectCreator"
    "roles/browser"
    # --- Billing & Quota ---
    "roles/billing.user"
    "roles/serviceusage.serviceUsageAdmin"
    # --- Security & IAM ---
    "roles/iam.securityAdmin"
    "roles/orgpolicy.policyAdmin"
    "roles/accesscontextmanager.policyAdmin"
    # --- Network ---
    "roles/compute.xpnAdmin"
    # --- Monitoring, Logging & Assets ---
    "roles/logging.admin"
    "roles/monitoring.admin"
    "roles/cloudasset.owner"
    # --- Tags ---
    "roles/resourcemanager.tagAdmin"
    "roles/resourcemanager.tagUser"
)

for role in "${ROLES[@]}"; do
    gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="$role" --quiet >/dev/null 2>&1
done

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" --member="user:$(gcloud config get-value account)" --role="roles/iam.serviceAccountTokenCreator" --project="${MGMT_PROJECT_ID}" --quiet >/dev/null 2>&1
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET_TFSTATE}" --member="serviceAccount:${SA_EMAIL}" --role="roles/storage.objectAdmin" --quiet >/dev/null 2>&1

print_info "Granting Billing User role to Service Account directly on the Billing Account..."
gcloud beta billing accounts add-iam-policy-binding "${BILLING_ACCOUNT_ID}"   --member="serviceAccount:${SA_EMAIL}"   --role="roles/billing.user"   --quiet >/dev/null 2>&1

# --- Step 7: File Generation ---
print_info "Updating configuration files..."
CURRENT_LINK_STATUS="true" # Billing is now fully automated

cat <<EOF > "${COMMON_VARS_PATH}"
terraform_service_account_email = "${SA_EMAIL}"
gcs_backend_bucket              = "${GCS_BUCKET_TFSTATE}"
organization_domain             = "${CUSTOMER_DOMAIN}"
billing_account_id              = "${BILLING_ACCOUNT_ID}"
gcp_region                      = "${GCP_REGION}"
project_id_prefix               = "${PROJECT_ID_PREFIX}"
core_billing_linked             = ${CURRENT_LINK_STATUS}
enable_vpc_host_projects        = ${ENABLE_VPC}
enable_shared_vpc               = ${ENABLE_VPC}
enable_vpc_sc                   = ${ENABLE_VPC_SC}
enable_org_policies             = ${ENABLE_ORG_POLICIES}
enable_tags                     = ${ENABLE_TAGS}
enable_simplified_admin_groups  = ${ENABLE_SIMPLIFIED_GROUPS}
allow_resource_destruction      = false
EOF

cat <<EOF > "${REPO_ROOT}/terraform/common.tfbackend"
bucket = "${GCS_BUCKET_TFSTATE}"
EOF

for dir in "0_bootstrap" "0_bootstrap/iam" "0_bootstrap/google_project_service"; do
    mkdir -p "${REPO_ROOT}/terraform/${dir}"
    cat <<EOF > "${REPO_ROOT}/terraform/${dir}/terraform.tfvars"
project_id = "${MGMT_PROJECT_ID}"
EOF
done

# --- Step 8: Apply Bootstrap ---
print_info "Applying Layer 0 (Bootstrap) using Terraform..."
export TF_IN_AUTOMATION="true"

for dir in "0_bootstrap" "0_bootstrap/iam" "0_bootstrap/google_project_service"; do
    print_info "Applying ${dir}..."
    cd "${REPO_ROOT}/terraform/${dir}"
    
    if [ "$dir" == "0_bootstrap" ]; then
        terraform init -backend-config="../common.tfbackend" -reconfigure >/dev/null
        terraform apply -var-file="../common.tfvars" -var-file="terraform.tfvars" -auto-approve
    else
        terraform init -backend-config="../../common.tfbackend" -reconfigure >/dev/null
        terraform apply -var-file="../../common.tfvars" -var-file="terraform.tfvars" -auto-approve
    fi
    cd "${REPO_ROOT}"
done

print_success "Setup Complete. Resources verified. Now run 'make generate' and 'make deploy'."
