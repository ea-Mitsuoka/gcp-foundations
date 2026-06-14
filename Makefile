# GCP Foundations Makefile

.PHONY: help install setup check generate lint opa test test-tf test-py deploy destroy delivery delivery-doc clean template prune

help:
	@echo "Available commands:"
	@echo "  make install   - Install required Python dependencies using uv"
	@echo "  make setup     - Initialize GCP seed resources for a new client"
	@echo "  make check     - Pre-flight check for GCP permissions, billing, and APIs"
	@echo "  make template  - Generate a blank gcp-foundations.xlsx with suggestion dropdowns"
	@echo "  make generate  - Generate Terraform resources from gcp-foundations.xlsx"
	@echo "  make lint      - Run terraform fmt, tflint, and shellcheck"
	@echo "  make opa       - Run OPA policy checks"
	@echo "  make test      - Run all tests (TF and Python)"
	@echo "  make deploy    - Run the global deployment script"
	@echo "  make destroy   - (DANGEROUS) Destroy all resources. Requires 'allow_resource_destruction=true' in common.tfvars"
	@echo "  make delivery  - Generate the delivery document, then prepare repository for handover (reset Git history)"
	@echo "  make delivery-doc - Generate only the delivery document (構築設定明細書) under delivery/"
	@echo "  make test-mode - Toggle test mode (random prefix & skip management projects)"
	@echo "  make prune     - Remove orphan 4_projects/ directories not defined in SSoT (Excel)"
	@echo "  make clean     - Remove local terraform state and cache files"

install:
	uv sync

setup:
	bash terraform/scripts/setup_new_client.sh

check:
	bash terraform/scripts/preflight_check.sh

template:
	uv run terraform/scripts/generate_template.py

generate:
	uv run terraform/scripts/generate_resources.py
	cd terraform && terraform fmt -recursive

lint:
	tflint --init
	tflint --recursive --config $(shell pwd)/.tflint.hcl --chdir terraform
	cd terraform && terraform fmt -recursive -check || (echo "⚠️ Formatting issues found. Running auto-fix..."; cd terraform && terraform fmt -recursive)
	find terraform/scripts -name "*.sh" -exec shellcheck -s bash {} +
	@echo ""
	@echo "✅ Lint check passed! Next: Run 'make deploy' to apply changes."

opa:
	opa check policies/*.rego

test: test-tf test-py

test-tf:
	@for dir in terraform/modules/*/; do \
		echo "Testing $$dir..."; \
		(cd "$$dir" && terraform init -backend=false > /dev/null && terraform test) || exit 1; \
	done

test-py:
	uv run pytest tests/

deploy:
	@if [ -f .test_mode_env ]; then \
		echo "🧪 Test Mode Active: Skipping management projects (logsink/monitoring)."; \
		. ./.test_mode_env && export SKIP_MANAGEMENT_PROJECTS=true && bash terraform/scripts/deploy_all.sh; \
	else \
		bash terraform/scripts/deploy_all.sh; \
	fi

destroy:
	@if [ -f .test_mode_env ]; then \
		echo "🧪 Test Mode Active: Skipping management projects (logsink/monitoring)."; \
		. ./.test_mode_env && export SKIP_MANAGEMENT_PROJECTS=true && bash terraform/scripts/destroy_all.sh $(filter-out $@,$(MAKECMDGOALS)); \
	else \
		bash terraform/scripts/destroy_all.sh $(filter-out $@,$(MAKECMDGOALS)); \
	fi

# 任意の引数（--all や --from-layer=X など）をMakeのエラーにしないためのダミーターゲット
%:
	@:

delivery: delivery-doc
	bash terraform/scripts/handover.sh

delivery-doc:
	uv run terraform/scripts/generate_delivery.py

test-mode:
	uv run python terraform/scripts/toggle_test_mode.py

prune:
	uv run terraform/scripts/prune_orphans.py

clean:
	find terraform -type d -name ".terraform" -exec rm -rf {} +
	find terraform -type f -name ".terraform.lock.hcl" -exec rm -f {} +
	find . -type d -name "__pycache__" -exec rm -rf {} +
