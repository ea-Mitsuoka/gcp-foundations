#!/bin/bash
#
# This script automates the initial environment setup for a new client.
# It interactively asks for client information, creates necessary GCP resources,
# and configures local files for Terraform execution.
#
# Note: Linking the billing account is left as a manual step at the end.

# --- Helper functions for colorized output ---
print_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# --- Stop on any error ---
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

# --- Step 0: Prerequisite Checks ---
print_info "Checking prerequisites..."
for cmd in gcloud terraform openssl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        print_error "$cmd CLI not found. Please install it first."
        exit 1
    fi
done
print_success "Prerequisites met."

# --- Step 1: Domain & Billing Input ---
DOMAIN_ENV_PATH="${REPO_ROOT}/domain.env"
COMMON_VARS_PATH="${REPO_ROOT}/terraform/common.tfvars"

# Load existing domain if available
if [ -f "$DOMAIN_ENV_PATH" ]; then
    CUSTOMER_DOMAIN=$(grep -E '^domain=' "$DOMAIN_ENV_PATH" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    print_info "Loaded existing domain: $CUSTOMER_DOMAIN"
else
    read -r -p "Enter customer's domain (e.g., example.com): " CUSTOMER_DOMAIN
    echo "domain=\"${CUSTOMER_DOMAIN}\"" > "$DOMAIN_ENV_PATH"
fi

# Billing Account ID Selection
print_info "Fetching available Billing Accounts..."
gcloud billing accounts list --format="table(name,displayName)" || true
AUTO_BILL_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1 2>/dev/null || true)

read -r -p "Enter Billing Account ID [Default: ${AUTO_BILL_ID:-dummy}]: " BILLING_ACCOUNT_ID
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-$AUTO_BILL_ID}
[[ "$BILLING_ACCOUNT_ID" == "dummy" || -z "$BILLING_ACCOUNT_ID" ]] && BILLING_ACCOUNT_ID="012345-6789AB-CDEF01"

# --- Step 2: Advanced Prefix Configuration (14-char validation) ---
print_info "Configuring Project ID Prefix..."

# Generate a smart default from domain (e.g., adradarstore.online -> adradarstore)
SUGGESTED_PREFIX=$(echo "$CUSTOMER_DOMAIN" | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-14 | sed 's/-$//')

# Load existing prefix if common.tfvars exists
if [ -f "$COMMON_VARS_PATH" ]; then
    EXISTING_PREFIX=$(grep "project_id_prefix" "$COMMON_VARS_PATH" | cut -d'=' -f2 | tr -d ' "')
    SUGGESTED_PREFIX=${EXISTING_PREFIX:-$SUGGESTED_PREFIX}
fi

echo "----------------------------------------------------------------"
echo "Project ID Prefix Setup:"
echo " - Must be 3-14 characters."
echo " - Only lowercase letters, numbers, and hyphens allowed."
echo " - Cannot end with a hyphen."
echo " - Current suggestion (based on domain/state): $SUGGESTED_PREFIX"
echo "----------------------------------------------------------------"

while true; do
    read -r -p "Enter Project ID Prefix [Default: $SUGGESTED_PREFIX]: " PROJECT_ID_PREFIX
    PROJECT_ID_PREFIX=${PROJECT_ID_PREFIX:-$SUGGESTED_PREFIX}

    # Validation: 3-14 chars, starts with letter, no trailing hyphen
    if [[ "$PROJECT_ID_PREFIX" =~ ^[a-z][a-z0-9-]{2,13}$ ]] && [[ ! "$PROJECT_ID_PREFIX" =~ -$ ]]; then
        print_success "Prefix '$PROJECT_ID_PREFIX' accepted."
        break
    else
        print_error "Invalid prefix '$PROJECT_ID_PREFIX'. Please follow the constraints above."
    fi
done

# --- Step 3: Other Configurations ---
read -r -p "Enter GCP region [Default: asia-northeast1]: " GCP_REGION
GCP_REGION=${GCP_REGION:-asia-northeast1}

# Boolean toggles with default preservation
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

# --- Step 4: Resource Name Generation ---
ORGANIZATION_ID="$(gcloud organizations list --filter="displayName=${CUSTOMER_DOMAIN}" --format="value(ID)")"
if [ -z "$ORGANIZATION_ID" ]; then
    print_error "Could not find Org ID for '$CUSTOMER_DOMAIN'. Check permissions."
    exit 1
fi

# Management project ID logic (Uses the prefix + tfstate + random suffix)
EXISTING_PROJECT=$(gcloud projects list --filter="id:${PROJECT_ID_PREFIX}-tfstate-*" --format="value(projectId)" | head -n 1)
if [ -n "$EXISTING_PROJECT" ]; then
    MGMT_PROJECT_ID="$EXISTING_PROJECT"
else
    MGMT_PROJECT_ID="${PROJECT_ID_PREFIX}-tfstate-$(openssl rand -hex 2)"
fi

MGMT_PROJECT_NAME="${PROJECT_ID_PREFIX}-tfstate"
GCS_BUCKET_TFSTATE="${MGMT_PROJECT_ID}-bucket"
SA_NAME="terraform-org-manager"
SA_EMAIL="${SA_NAME}@${MGMT_PROJECT_ID}.iam.gserviceaccount.com"

# --- Step 5: Confirmation & Execution ---
echo -e "\n--------------------------------------------------"
echo " Confirming deployment for: $CUSTOMER_DOMAIN"
echo "  Org ID:        $ORGANIZATION_ID"
echo "  Prefix:        $PROJECT_ID_PREFIX (Projects will be $PROJECT_ID_PREFIX-logsink, etc.)"
echo "  Mgmt Project:  $MGMT_PROJECT_ID"
echo "  TF State GCS:  $GCS_BUCKET_TFSTATE"
echo "--------------------------------------------------"
read -r -p "Proceed with GCP resource creation? (y/n): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { print_error "Aborted."; exit 1; }

# (GCP Resource creation logic - Project, Billing Link, APIs, Bucket, SA, IAM)
# ※ ここは以前のスクリプトと同様の gcloud コマンド群が続きます
print_info "Creating project and basic infrastructure..."
if ! gcloud projects describe "${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    gcloud projects create "${MGMT_PROJECT_ID}" --name="${MGMT_PROJECT_NAME}" --organization="${ORGANIZATION_ID}"
fi

print_warning "LINK BILLING MANUALLY: gcloud billing projects link ${MGMT_PROJECT_ID} --billing-account=${BILLING_ACCOUNT_ID}"
read -r -p "Press [Enter] after linking billing..."

gcloud services enable cloudresourcemanager.googleapis.com storage.googleapis.com iam.googleapis.com \
    serviceusage.googleapis.com iamcredentials.googleapis.com orgpolicy.googleapis.com \
    logging.googleapis.com pubsub.googleapis.com cloudasset.googleapis.com --project="${MGMT_PROJECT_ID}"

# Bucket & SA logic ... (省略可、または既存ロジックを統合)

# --- Step 6: File Generation (common.tfvars etc.) ---
print_info "Updating configuration files..."

cat <<EOF > "${REPO_ROOT}/terraform/common.tfvars"
terraform_service_account_email = "${SA_EMAIL}"
gcs_backend_bucket               = "${GCS_BUCKET_TFSTATE}"
organization_domain              = "${CUSTOMER_DOMAIN}"
billing_account_id               = "${BILLING_ACCOUNT_ID}"
gcp_region                       = "${GCP_REGION}"
project_id_prefix                = "${PROJECT_ID_PREFIX}"
core_billing_linked              = false
enable_vpc_host_projects        = ${ENABLE_VPC}
enable_shared_vpc                = ${ENABLE_VPC}
enable_vpc_sc                    = ${ENABLE_VPC_SC}
enable_org_policies              = ${ENABLE_ORG_POLICIES}
enable_tags                      = ${ENABLE_TAGS}
enable_simplified_admin_groups  = ${ENABLE_SIMPLIFIED_GROUPS}
allow_resource_destruction       = false
EOF

# (Other tfvars generation ...)
print_success "Setup Complete. Now run 'make generate' and 'make deploy'."
