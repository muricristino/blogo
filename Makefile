SHELL = /bin/sh
.ONESHELL:
.DEFAULT_GOAL: help

help: ## Display this help menu
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z\._-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

dev.up: ## Start the development environment (with build)
	@docker compose up --build -d

dev.down: ## Stop the development environment and remove volumes
	@docker compose down -v

dev.test: ## Run tests
	@docker compose exec api go test -v ./...

dev.logs: ## Follow application container logs
	@docker compose logs -f api

dev.shell: ## Open a shell inside the development container
	@docker compose exec api bash

dev.tidy: ## Tidy Go dependencies
	@docker compose exec api go mod tidy

dev.fmt: ## Format Go code
	@docker compose exec api go fmt ./...

dev.db: ## Open the database shell
	@docker compose exec db ./cockroach sql --insecure

