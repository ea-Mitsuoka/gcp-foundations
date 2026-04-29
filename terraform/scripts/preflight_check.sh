#!/bin/bash
#
# Pre-flight Check Script for GCP Foundations
# Validates GCP connectivity, permissions, billing, and APIs before deployment.

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
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
COMMON_TFVARS="${REPO_ROOT}/terraform/common.tfvars"

if [ ! -f "$COMMON_TFVARS" ]; then
    print_error "common.tfvars not found. Run 'make setup' first."
    exit 1
fi

# Extract Management Project ID from bootstrap tfvars
MGMT_PROJECT_ID=$(grep "project_id" "${REPO_ROOT}/terraform/0_bootstrap/terraform.tfvars" | cut -d'=' -f2 | tr -d ' "')

print_info "Starting Pre-flight Check..."
echo "--------------------------------------------------"

# 1. Check gcloud authentication
print_info "Checking gcloud authentication..."
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [ -z "$ACTIVE_ACCOUNT" ]; then
    print_error "No active gcloud account found. Run 'gcloud auth login' and 'gcloud auth application-default login'."
    exit 1
fi
print_success "Authenticated as: $ACTIVE_ACCOUNT"

# 2. Check Management Project existence
print_info "Checking management project: $MGMT_PROJECT_ID..."
if ! gcloud projects describe "$MGMT_PROJECT_ID" &>/dev/null; then
    print_error "Cannot access management project '$MGMT_PROJECT_ID'. Check your permissions."
    exit 1
fi
print_success "Project access confirmed."

# 3. Check Billing Account link
print_info "Checking billing account linkage..."
BILLING_INFO=$(gcloud billing projects describe "$MGMT_PROJECT_ID" --format="value(billingEnabled)")
if [ "$BILLING_INFO" != "True" ]; then
    print_error "Project '$MGMT_PROJECT_ID' is not linked to an active billing account."
    exit 1
fi
print_success "Billing account linked."

# 4. Check essential APIs
print_info "Checking essential APIs..."
REQUIRED_APIS=(
    "cloudresourcemanager.googleapis.com"
    "serviceusage.googleapis.com"
    "iam.googleapis.com"
    "storage.googleapis.com"
)

ENABLED_APIS=$(gcloud services list --enabled --project="$MGMT_PROJECT_ID" --format="value(config.name)")
MISSING_APIS=()

for api in "${REQUIRED_APIS[@]}"; do
    if ! echo "$ENABLED_APIS" | grep -q "$api"; then
        MISSING_APIS+=("$api")
    fi
done

if [ ${#MISSING_APIS[@]} -ne 0 ]; then
    print_error "The following essential APIs are not enabled on '$MGMT_PROJECT_ID':"
    for api in "${MISSING_APIS[@]}"; do echo "  - $api"; done
    exit 1
fi
print_success "Essential APIs are enabled."

# 5. Check terraform/0_bootstrap state (Basic check if init has run)
print_info "Checking local terraform state..."
if [ ! -d "${REPO_ROOT}/terraform/0_bootstrap/.terraform" ]; then
    print_warning "Layer 0_bootstrap has not been initialized. Run 'make deploy' to start."
fi

echo "--------------------------------------------------"
print_success "Pre-flight Check passed! Environment is ready for deployment."
echo
