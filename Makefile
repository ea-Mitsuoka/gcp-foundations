# GCP Foundations Makefile

.PHONY: help install generate lint opa test deploy clean

help:
	@echo "Available commands:"
	@echo "  make install   - Install required Python dependencies using uv"
	@echo "  make generate  - Generate Terraform resources from gcp_foundations.xlsx"
	@echo "  make lint      - Run terraform fmt, tflint, and shellcheck"
	@echo "  make opa       - Run OPA policy checks"
	@echo "  make test      - Run terraform tests in modules directory"
	@echo "  make deploy    - Run the global deployment script"
	@echo "  make clean     - Remove local terraform state and cache files"

install:
	uv sync

generate:
	uv run terraform/scripts/generate_resources.py

lint:
	cd terraform && terraform fmt -recursive
	cd terraform && tflint --init && tflint --recursive
	find terraform/scripts -name "*.sh" -exec shellcheck -s bash {} +

opa:
	opa check policies/*.rego

test:
	@for dir in terraform/modules/*/; do \
		echo "Testing $$dir..."; \
		(cd "$$dir" && terraform init -backend=false > /dev/null && terraform test) || exit 1; \
	done

deploy:
	bash terraform/scripts/deploy_all.sh

clean:
	find terraform -type d -name ".terraform" -exec rm -rf {} +
	find terraform -type f -name ".terraform.lock.hcl" -exec rm -f {} +
	find . -type d -name "__pycache__" -exec rm -rf {} +
