# Simple Makefile for Sleeper DB project

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'

.PHONY: up
up: ## Start all services
	docker compose up -d

.PHONY: down
down: ## Stop all services
	docker compose down

.PHONY: clean
clean: ## Stop services and remove volumes
	docker compose down -v

.PHONY: logs
logs: ## Show all logs
	docker compose logs -f

.PHONY: logs-db
logs-db: ## Show database logs
	docker compose logs -f postgres

.PHONY: logs-hasura
logs-hasura: ## Show Hasura logs
	docker compose logs -f hasura

.PHONY: ps
ps: ## Show running containers
	docker compose ps

.PHONY: db-console
db-console: ## Open PostgreSQL console
	docker compose exec postgres psql -U sleeper_user -d sleeper_db

.PHONY: hasura-console
hasura-console: ## Open Hasura console in browser
	@echo "Opening http://localhost:8080"
	@echo "Admin secret: changeme"
	@open http://localhost:8080 2>/dev/null || xdg-open http://localhost:8080 2>/dev/null || echo "Please open http://localhost:8080 in your browser"

.PHONY: rebuild
rebuild: clean ## Clean rebuild everything
	docker compose build --no-cache
	docker compose up -d

# Sync Service Commands
.PHONY: build-sync
build-sync: ## Build sync service
	docker compose build sync

.PHONY: logs-sync
logs-sync: ## Show sync service logs
	docker compose logs -f sync

.PHONY: sync-all
sync-all: ## Run full data sync
	docker compose exec sync /app/sleeper-sync sync all

.PHONY: sync-incremental
sync-incremental: ## Run incremental sync
	docker compose exec sync /app/sleeper-sync sync incremental

.PHONY: sync-league
sync-league: ## Sync specific league (usage: make sync-league LEAGUE_ID=xxx)
	@if [ -z "$(LEAGUE_ID)" ]; then \
		echo "Error: LEAGUE_ID is required. Usage: make sync-league LEAGUE_ID=xxx"; \
		exit 1; \
	fi
	docker compose exec sync /app/sleeper-sync sync league $(LEAGUE_ID)

.PHONY: sync-user
sync-user: ## Sync user's leagues (usage: make sync-user USER_ID=xxx)
	@if [ -z "$(USER_ID)" ]; then \
		echo "Error: USER_ID is required. Usage: make sync-user USER_ID=xxx"; \
		exit 1; \
	fi
	docker compose exec sync /app/sleeper-sync sync user $(USER_ID)

.PHONY: sync-health
sync-health: ## Check sync service health
	@curl -s http://localhost:8082/health | jq . || echo "Sync service not responding"

.PHONY: metrics
metrics: ## Show Prometheus metrics
	@curl -s http://localhost:9090/metrics | head -20