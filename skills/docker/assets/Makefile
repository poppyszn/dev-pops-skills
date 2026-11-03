.PHONY: help \
	dev \
	docker-dev-env docker-dev docker-dev-down docker-dev-db docker-dev-db-down \
	docker-dev-apps docker-dev-logs docker-dev-clean \
	docker-migrate-dev docker-seed-dev \
	docker-deploy-pull docker-deploy docker-deploy-down \
	docker-migrate-deploy docker-seed-deploy

COMPOSE_FILE ?= docker/node-api/compose.yml
DEPLOY_COMPOSE_FILE ?= docker/node-api/compose.deploy.yml
DEPLOY_COMPOSE = docker compose -f $(DEPLOY_COMPOSE_FILE) --env-file .env

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Local development (native, no Docker)

dev: ## Run the app dev server
	npm run dev

##@ Local Docker stack (build images locally)

# Bootstraps .env from .env.example on first use. If .env already exists,
# this rule is a no-op — Make only runs it when the file is missing.
.env:
	cp .env.example .env
	@echo "Created .env from .env.example — edit it if you need different local values."

docker-dev-env: ## Force-sync .env from .env.example (overwrites existing values)
	cp .env.example .env
	@echo ".env synced from .env.example."

docker-dev: .env ## Start the full local stack: infra + app (builds images)
	docker compose -f $(COMPOSE_FILE) up -d --build --wait

docker-dev-down: ## Stop the local stack
	docker compose -f $(COMPOSE_FILE) down

docker-dev-db: .env ## Start infra only (postgres, redis)
	docker compose -f $(COMPOSE_FILE) up -d postgres redis --wait

docker-dev-db-down: ## Stop infra only
	docker compose -f $(COMPOSE_FILE) stop postgres redis

docker-dev-apps: .env ## Start the app only (assumes infra already running)
	docker compose -f $(COMPOSE_FILE) up -d --build api

docker-dev-logs: ## Tail logs for the local stack
	docker compose -f $(COMPOSE_FILE) logs -f

docker-migrate-dev: .env ## Run migrations against the local stack
	docker compose -f $(COMPOSE_FILE) run --rm migrate

docker-seed-dev: .env ## Run the seed job against the local stack
	docker compose -f $(COMPOSE_FILE) --profile seed run --rm seed

docker-dev-clean: ## Stop the local stack and remove volumes
	docker compose -f $(COMPOSE_FILE) down -v

##@ Deploy-style stack (pulls built images, no local build)

docker-deploy-pull: ## Pull the latest built images
	$(DEPLOY_COMPOSE) pull

docker-deploy: .env ## Start the stack from pulled images
	$(DEPLOY_COMPOSE) up -d --wait

docker-deploy-down: ## Stop the pulled-image stack
	$(DEPLOY_COMPOSE) down

docker-migrate-deploy: .env ## Run migrations against the pulled-image stack
	$(DEPLOY_COMPOSE) run --rm migrate

docker-seed-deploy: .env ## Run the seed job against the pulled-image stack
	$(DEPLOY_COMPOSE) --profile seed run --rm seed

.DEFAULT_GOAL := help
