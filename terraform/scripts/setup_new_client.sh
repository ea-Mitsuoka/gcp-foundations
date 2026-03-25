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
print_info "Please provide the following information for the new client."
read -r -p "Enter customer's domain (e.g., customer-domain.com): " CUSTOMER_DOMAIN
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

# Generate resource names
ORG_NAME_FOR_ID="$(echo "$CUSTOMER_DOMAIN" | tr '.' '-')"
SUFFIX="$(openssl rand -hex 2)"
MGMT_PROJECT_ID="${ORG_NAME_FOR_ID}-tf-admin-${SUFFIX}"
MGMT_PROJECT_NAME="${ORG_NAME_FOR_ID}-tf-admin"
GCS_BUCKET_TFSTATE="${MGMT_PROJECT_ID}-tfstate"
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
if [[ "$confirm" != "y" ]]; then
    print_error "Operation aborted by user."
    exit 1
fi
echo

# --- Step 3: Automated GCP Resource Creation ---
print_info "Starting automated GCP resource creation..."

print_info "(3.1/5) Creating management project '${MGMT_PROJECT_ID}'..."
gcloud projects create "${MGMT_PROJECT_ID}" \
  --name="${MGMT_PROJECT_NAME}" \
  --organization="${ORGANIZATION_ID}"
print_success "Project created."

print_info "(3.2/5) Enabling necessary APIs on the project..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com \
  --project="${MGMT_PROJECT_ID}"
print_success "APIs enabled."

print_info "(3.3/5) Creating GCS bucket 'gs://${GCS_BUCKET_TFSTATE}'..."
gcloud storage buckets create "gs://${GCS_BUCKET_TFSTATE}" \
  --project="${MGMT_PROJECT_ID}" \
  --location="${GCP_REGION}" \
  --uniform-bucket-level-access
gcloud storage buckets update "gs://${GCS_BUCKET_TFSTATE}" --versioning
print_success "GCS bucket created and versioning enabled."

print_info "(3.4/5) Creating service account '${SA_NAME}'..."
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="Terraform Organization Manager" \
  --project="${MGMT_PROJECT_ID}"
print_success "Service account created."

print_info "(3.5/5) Granting IAM permissions..."
# Grant org-level roles to the SA
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.organizationViewer" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.folderAdmin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.projectCreator" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/billing.user" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/logging.admin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/iam.securityAdmin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/serviceusage.admin" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/monitoring.viewer" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/cloudasset.owner" --quiet
gcloud organizations add-iam-policy-binding "${ORGANIZATION_ID}" --member="serviceAccount:${SA_EMAIL}" --role="roles/resourcemanager.projectViewer" --quiet

# Allow current user to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="${MGMT_PROJECT_ID}"

# Allow SA to manage the GCS bucket
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET_TFSTATE}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"
print_success "IAM permissions granted."
echo

# --- Step 4: Local File Configuration ---
print_info "Configuring local files..."

# Create domain.env
printf 'domain="%s"\n' "${CUSTOMER_DOMAIN}" > "${REPO_ROOT}/domain.env"
print_success "Created domain.env"

# Create common.tfvars
printf 'terraform_service_account_email="%s"\n' "${SA_EMAIL}" > "${REPO_ROOT}/terraform/common.tfvars"
print_success "Created terraform/common.tfvars"

# Create common.tfbackend
cat << EOF2 > "${REPO_ROOT}/terraform/common.tfbackend"
bucket = "${GCS_BUCKET_TFSTATE}"
EOF2
print_success "Created terraform/common.tfbackend"
echo

# --- Step 5: Manual Action Required ---
print_warning "-------------------- MANUAL ACTION REQUIRED --------------------"
print_info "The automated setup is almost complete."
print_info "As per your requirement, you must link the billing account manually."
print_info "Please copy and run the following command, replacing <YOUR_BILLING_ID> with the actual Billing Account ID:"
echo
echo "gcloud billing projects link ${MGMT_PROJECT_ID} --billing-account=<YOUR_BILLING_ID>"
echo
print_warning "----------------------------------------------------------------"
echo

# --- Step 6: Next Steps ---
print_success "Initial environment setup is complete!"
print_info "After linking the billing account, please proceed with the following steps:"
echo "1. cd terraform/0_bootstrap"
echo '2. terraform init -backend-config="../common.tfbackend"'
echo '3. terraform apply -var-file="../common.tfvars"'
echo

exit 0
