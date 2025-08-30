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

.PHONY: uninstall
uninstall: ## Complete uninstall - runs the uninstall.sh script
	@./uninstall.sh