#!/bin/bash
#
# This script automates the initial environment setup for a new client.
# It interactively asks for client information, creates necessary GCP resources,
# and configures local files for Terraform execution.
#
# Note: Linking the billing account is left as a manual step at the end.

# --- Helper functions for colorized output ---
print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}
print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}
print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}
print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# --- Stop on any error ---
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [ -z "$REPO_ROOT" ]; then
    print_error "Git repository root could not be determined. Run this script inside the repository."
    exit 1
fi

# --- Step 0: Prerequisite Checks ---
print_info "Checking prerequisites..."
if ! command -v gcloud >/dev/null 2>&1; then
    print_error "gcloud CLI not found. Please install it first."
    exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
    print_error "terraform CLI not found. Please install it first."
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    print_error "openssl not found. Please install it first."
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    print_error "You are not logged into gcloud. Please run 'gcloud auth login' and 'gcloud auth application-default login' first."
    exit 1
fi
print_success "Prerequisites met."
echo

# --- Step 1: Interactive Information Input ---
DOMAIN_ENV_PATH="${REPO_ROOT}/domain.env"
if [ -f "$DOMAIN_ENV_PATH" ]; then
    print_info "Found domain.env. Reading domain..."
    CUSTOMER_DOMAIN=$(grep -E '^domain=' "$DOMAIN_ENV_PATH" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    print_success "Loaded domain: $CUSTOMER_DOMAIN"
else
    print_info "Please provide the following information for the new client."
    read -r -p "Enter customer's domain (e.g., customer-domain.com): " CUSTOMER_DOMAIN
    echo "domain=\"${CUSTOMER_DOMAIN}\"" > "$DOMAIN_ENV_PATH"
    print_success "Created domain.env with domain: $CUSTOMER_DOMAIN"
fi

read -r -p "Enter the GCP region for GCS buckets (e.g., asia-northeast1): " GCP_REGION

if [ -z "$CUSTOMER_DOMAIN" ] || [ -z "$GCP_REGION" ]; then
    print_error "Customer domain and GCP region cannot be empty."
    exit 1
fi
echo

# --- Step 2: Variable Configuration and Confirmation ---
print_info "Generating resource names based on your input..."

# Get Organization ID from domain
ORGANIZATION_ID="$(gcloud organizations list --filter="displayName=${CUSTOMER_DOMAIN}" --format="value(ID)")"
if [ -z "$ORGANIZATION_ID" ]; then
    print_error "Could not find Organization ID for domain '${CUSTOMER_DOMAIN}'. Please check the domain name and your permissions."
    exit 1
fi

# ドメイン名のドットをハイフンに変換 (例: adradarstore.online -> adradarstore-online)
ORG_NAME_FOR_ID="$(echo "$CUSTOMER_DOMAIN" | tr '.' '-')"

# 30文字制限のための計算 (-tfstate-xxxx で13文字使うため、ドメイン部分は17文字まで)
if [ ${#ORG_NAME_FOR_ID} -le 17 ]; then
    # 17文字以内なら全体を使用 (例: example.com -> example-com)
    SHORT_ORG_NAME="$ORG_NAME_FOR_ID"
else
    # 17文字を超える場合は、最初のドットより前の「プライマリドメイン」のみを抽出 (例: adradarstore.online -> adradarstore)
    PRIMARY_DOMAIN="$(echo "$CUSTOMER_DOMAIN" | cut -d'.' -f1)"
    # プライマリドメイン単体でも17文字を超える場合の安全対策
    SHORT_ORG_NAME="$(echo "$PRIMARY_DOMAIN" | cut -c1-17 | sed 's/-$//')"
fi

# すでに作成済みのプロジェクトがあるか検索する
EXISTING_PROJECT=$(gcloud projects list --filter="id:${SHORT_ORG_NAME}-tfstate-*" --format="value(projectId)" | head -n 1)

if [ -n "$EXISTING_PROJECT" ]; then
    print_info "Found existing project. Reusing: ${EXISTING_PROJECT}"
    MGMT_PROJECT_ID="${EXISTING_PROJECT}"
else
    SUFFIX="$(openssl rand -hex 2)"
    MGMT_PROJECT_ID="${SHORT_ORG_NAME}-tfstate-${SUFFIX}"
fi

MGMT_PROJECT_NAME="${SHORT_ORG_NAME}-tfstate"
GCS_BUCKET_TFSTATE="${MGMT_PROJECT_ID}-bucket"
SA_NAME="terraform-org-manager"
SA_EMAIL="${SA_NAME}@${MGMT_PROJECT_ID}.iam.gserviceaccount.com"

echo "--------------------------------------------------"
echo "The following resources will be created:"
echo "  Customer Domain:         ${CUSTOMER_DOMAIN}"
echo "  GCP Organization ID:     ${ORGANIZATION_ID}"
echo "  Management Project ID:   ${MGMT_PROJECT_ID}"
echo "  Management Project Name: ${MGMT_PROJECT_NAME}"
echo "  GCS Bucket for tfstate:  ${GCS_BUCKET_TFSTATE}"
echo "  Service Account Email:   ${SA_EMAIL}"
echo "--------------------------------------------------"
read -r -p "Do you want to proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_error "Operation aborted by user."
    exit 1
fi
echo

# --- Step 3: Automated GCP Resource Creation ---
print_info "Starting automated GCP resource creation..."

print_info "(3.1/5) Creating management project '${MGMT_PROJECT_ID}'..."
if gcloud projects describe "${MGMT_PROJECT_ID}" >/dev/null 2>&1; then
    print_success "Project already exists. Skipping creation."
else
    gcloud projects create "${MGMT_PROJECT_ID}" \
      --name="${MGMT_PROJECT_NAME}" \
      --organization="${ORGANIZATION_ID}"
    print_success "Project created."
fi

print_info "(3.2/5) Enabling necessary APIs on the project..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com \
  --project="${MGMT_PROJECT_ID}"
print_success "APIs enabled."

# --- (追加) 手動での請求先アカウント紐づけ待ち ---
echo
print_warning "-------------------- MANUAL ACTION REQUIRED --------------------"
print_info "GCP requires an active billing account to create GCS buckets."
print_info "Please open a NEW terminal window and run the following command,"
print_info "replacing <YOUR_BILLING_ID> with the actual Billing Account ID:"
echo
echo "  gcloud billing projects link ${MGMT_PROJECT_ID} --billing-account=<YOUR_BILLING_ID>"
echo
print_warning "----------------------------------------------------------------"
read -r -p "Press [Enter] AFTER you have successfully linked the billing account..."
echo

print_info "(3.3/5) Creating GCS bucket 'gs://${GCS_BUCKET_TFSTATE}'..."
if gcloud storage buckets describe "gs://${GCS_BUCKET_TFSTATE}" >/dev/null 2>&1; then
    print_success "Bucket already exists. Skipping creation."
else
    gcloud storage buckets create "gs://${GCS_BUCKET_TFSTATE}" \
      --project="${MGMT_PROJECT_ID}" \
      --location="${GCP_REGION}" \
      --uniform-bucket-level-access
    print_success "Bucket created."
fi

# バージョニングの有効化は、バケットが既存・新規に関わらず必ず実行する（冪等性があるため安全）
print_info "Ensuring versioning is enabled on the bucket..."
MAX_RETRIES=6
RETRY_COUNT=0
while ! gcloud storage buckets update "gs://${GCS_BUCKET_TFSTATE}" --project="${MGMT_PROJECT_ID}" --versioning >/dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    print_error "Failed to enable versioning after $MAX_RETRIES attempts."
    exit 1
  fi
  print_warning "Permission not yet propagated. Retrying in 10 seconds... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
done
print_success "GCS bucket versioning is enabled."

print_info "Waiting for IAM propagation to enable versioning (this may take up to a minute)..."

# バージョニングの有効化を最大6回（約60秒間）リトライする
MAX_RETRIES=6
RETRY_COUNT=0
while ! gcloud storage buckets update "gs://${GCS_BUCKET_TFSTATE}" --project="${MGMT_PROJECT_ID}" --versioning; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    print_error "Failed to enable versioning after $MAX_RETRIES attempts."
    exit 1
  fi
  print_warning "Permission not yet propagated. Retrying in 10 seconds... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
done

print_success "GCS bucket created and versioning enabled."

print_info "(3.4/5) Creating service account '${SA_NAME}'..."

# プロジェクト内のSA一覧から、該当のメールアドレスを持つSAを検索する
EXISTING_SA=$(gcloud iam service-accounts list --project="${MGMT_PROJECT_ID}" --filter="email=${SA_EMAIL}" --format="value(email)")

if [ -n "$EXISTING_SA" ]; then
    print_success "Service account already exists. Skipping creation."
else
    gcloud iam service-accounts create "${SA_NAME}" \
      --display-name="Terraform Organization Manager" \
      --project="${MGMT_PROJECT_ID}"
    print_success "Service account created."
fi

print_info "(3.5/5) Granting IAM permissions..."
print_info "Waiting for Service Account propagation to Organization IAM..."

# 最初の権限付与をリトライループで実行し、SAの伝播を待機する
MAX_RETRIES=6
RETRY_COUNT=0
while ! gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/resourcemanager.organizationViewer" \
  --quiet >/dev/null 2>&1; do

  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    print_error "Failed to apply IAM binding after $MAX_RETRIES attempts."
    exit 1
  fi
  print_warning "Service Account not yet recognized. Retrying in 10 seconds... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
done

print_info "Service Account recognized. Applying remaining IAM roles..."

# 組織(Organization)レベルの権限付与
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.folderAdmin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.projectCreator" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/billing.user" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/logging.admin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/iam.securityAdmin" --quiet
# 【修正箇所】ロール名のタイポを修正 (serviceusage.admin -> serviceusage.serviceUsageAdmin)
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/serviceusage.serviceUsageAdmin" --quiet
# 残りの組織レベルの権限付与
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/monitoring.viewer" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/cloudasset.owner" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/browser" --quiet

# Allow current user to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="${MGMT_PROJECT_ID}" --quiet

# Allow SA to manage the GCS bucket
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET_TFSTATE}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin" --quiet

print_success "IAM permissions granted."

print_info "(3.6/5) Generating common Terraform configuration files..."
cat <<EOF > "${REPO_ROOT}/terraform/common.tfbackend"
bucket = "${GCS_BUCKET_TFSTATE}"
EOF

cat <<EOF > "${REPO_ROOT}/terraform/common.tfvars"
terraform_service_account_email = "${SA_EMAIL}"
gcs_backend_bucket              = "${GCS_BUCKET_TFSTATE}"
organization_domain             = "${CUSTOMER_DOMAIN}"
gcp_region                      = "${GCP_REGION}
EOF

cat <<EOF > "${REPO_ROOT}/terraform/0_bootstrap/terraform.tfvars"
project_id = "${MGMT_PROJECT_ID}"
EOF
cat <<EOF > "${REPO_ROOT}/terraform/0_bootstrap/iam/terraform.tfvars"
project_id = "${MGMT_PROJECT_ID}"
EOF
cat <<EOF > "${REPO_ROOT}/terraform/0_bootstrap/google_project_service/terraform.tfvars"
project_id = "${MGMT_PROJECT_ID}"
EOF
print_success "Configuration files and tfvars generated successfully."
echo
