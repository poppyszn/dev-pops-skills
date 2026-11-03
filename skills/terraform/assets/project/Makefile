.PHONY: help fmt fmt-check validate parity check init plan apply lock

# Run from the terraform/ directory. ENV selects the environment for init, plan and apply.
ENV ?= development
ENV_DIR = environments/$(ENV)
ENVIRONMENTS = $(notdir $(patsubst %/,%,$(wildcard environments/*/)))
PLATFORMS = -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Checks (safe to run anywhere, no AWS credentials needed)

fmt: ## Format all .tf files
	terraform fmt -recursive

fmt-check: ## Fail if any .tf file is not formatted
	terraform fmt -check -recursive -diff

validate: ## Validate every environment (init without a backend)
	@set -e; for e in $(ENVIRONMENTS); do \
		echo "== $$e"; \
		terraform -chdir=environments/$$e init -backend=false -input=false >/dev/null; \
		terraform -chdir=environments/$$e validate; \
	done

parity: ## Fail if the environments have drifted apart
	./scripts/check-env-parity.sh

check: fmt-check validate parity ## Run every check above

##@ Plan and apply (need AWS credentials; ENV=production|staging|development)

init: ## Initialise ENV (uses backend.hcl when present, otherwise local state)
	@if [ -f $(ENV_DIR)/backend.hcl ]; then \
		terraform -chdir=$(ENV_DIR) init -input=false -backend-config=backend.hcl; \
	else \
		terraform -chdir=$(ENV_DIR) init -input=false; \
	fi

plan: init ## Show what applying ENV would change
	terraform -chdir=$(ENV_DIR) plan -input=false -var-file=terraform.tfvars

apply: init ## Apply ENV after reviewing the plan (asks for confirmation)
	terraform -chdir=$(ENV_DIR) apply -var-file=terraform.tfvars

lock: ## Re-write ENV's lock file with hashes for all common platforms
	terraform -chdir=$(ENV_DIR) providers lock $(PLATFORMS)
