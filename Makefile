# Shortcuts for common operations. Everything here is plain `docker compose`;
# run `make help` for the list.
.DEFAULT_GOAL := help
.PHONY: help init up down restart build upgrade ps logs url reload shell config lint

COMPOSE ?= docker compose
# Lint tool images are pinned in .github/lint/compose.yml (bumped by Dependabot);
# CI runs `make lint`, so both use the same shellcheck/hadolint versions.
LINT := $(COMPOSE) -f .github/lint/compose.yml run --rm
HOST ?=

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Create .env + mounted dirs (HOST=<ip|domain|url> to set the public address)
	./scripts/init.sh $(HOST)

up: ## Build (if needed) and start in the background
	$(COMPOSE) up -d --build

down: ## Stop and remove containers (data in ./data is kept)
	$(COMPOSE) down

restart: ## Restart dsh (issues a new startup token)
	$(COMPOSE) restart dsh

build: ## Rebuild the dsh image
	$(COMPOSE) build dsh

upgrade: ## Rebuild with the DSH_VERSION from .env and recreate
	$(COMPOSE) build --pull dsh
	$(COMPOSE) up -d

ps: ## Show container status
	$(COMPOSE) ps

logs: ## Follow logs of all services
	$(COMPOSE) logs -f --tail=100

url: ## Print the login URL (contains the startup token)
	@./scripts/show-url.sh

reload: ## Validate and hot-reload nginx config
	$(COMPOSE) exec nginx nginx -t
	$(COMPOSE) exec nginx nginx -s reload

shell: ## Open a shell inside the dsh container
	$(COMPOSE) exec dsh bash

config: ## Print the resolved compose config
	$(COMPOSE) config

lint: ## Lint shell scripts, Dockerfile and compose file (pinned tool images)
	$(LINT) shellcheck $(wildcard scripts/*.sh) dsh/entrypoint.sh
	$(LINT) hadolint
	$(COMPOSE) --env-file .env.example config -q
