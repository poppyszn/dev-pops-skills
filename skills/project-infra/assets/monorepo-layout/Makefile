.PHONY: help \
	dev-api dev-web dev-admin \
	docker-dev-env docker-dev docker-dev-down docker-dev-db docker-dev-db-down \
	docker-dev-apps docker-dev-logs docker-dev-clean \
	docker-migrate-dev docker-seed-dev \
	docker-deploy-pull docker-deploy docker-deploy-down \
	docker-migrate-deploy docker-seed-deploy

DEPLOY_COMPOSE = docker compose -f docker/develop/compose.yml --env-file docker/develop/.env

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Local development (native, no Docker)

dev-api: ## Run the API dev server
	npm run dev --workspace=apps/api

dev-web: ## Run the web (Next.js) dev server
	npm run dev --workspace=apps/web

dev-admin: ## Run the admin dev server
	npm run dev --workspace=apps/admin

##@ Local Docker stack (build images locally)

# Bootstraps .env from .env.example on first use. If .env already exists,
# this rule is a no-op — Make only runs it when the file is missing.
.env:
	cp .env.example .env
	@echo "Created .env from .env.example — edit it if you need different local values."

docker-dev-env: ## Force-sync .env from .env.example (overwrites existing values)
	cp .env.example .env
	@echo ".env synced from .env.example."

docker-dev: .env ## Start the full local stack: infra + all apps (builds images)
	docker compose up -d --build --wait

docker-dev-down: ## Stop the local stack
	docker compose down

docker-dev-db: .env ## Start infra only (postgres, redis)
	docker compose up -d postgres redis --wait

docker-dev-db-down: ## Stop infra only
	docker compose stop postgres redis

docker-dev-apps: .env ## Start apps only (assumes infra already running)
	docker compose up -d --build api web admin

docker-dev-logs: ## Tail logs for the local stack
	docker compose logs -f

docker-migrate-dev: .env ## Run migrations against the local stack
	docker compose run --rm migrate

docker-seed-dev: .env ## Run the seed job against the local stack
	docker compose --profile seed run --rm seed

docker-dev-clean: ## Stop the local stack and remove volumes
	docker compose down -v

##@ Deploy-style stack (docker/develop/compose.yml — pulls built images)

docker-deploy-pull: ## Pull the latest built images
	$(DEPLOY_COMPOSE) pull

docker-deploy: ## Start the stack from pulled images
	$(DEPLOY_COMPOSE) up -d --wait

docker-deploy-down: ## Stop the pulled-image stack
	$(DEPLOY_COMPOSE) down

docker-migrate-deploy: ## Run migrations against the pulled-image stack
	$(DEPLOY_COMPOSE) run --rm migrate

docker-seed-deploy: ## Run the seed job against the pulled-image stack
	$(DEPLOY_COMPOSE) --profile seed run --rm seed

.DEFAULT_GOAL := help
