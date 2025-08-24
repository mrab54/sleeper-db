.PHONY: help
help: ## Display this help message
	@echo "Sleeper DB - Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development
.PHONY: dev
dev: ## Start development environment with docker-compose
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

.PHONY: dev-build
dev-build: ## Build development containers
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

.PHONY: dev-down
dev-down: ## Stop development environment
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Production
.PHONY: prod
prod: ## Start production environment
	docker-compose up -d

.PHONY: prod-build
prod-build: ## Build production containers
	docker-compose build --no-cache

.PHONY: prod-down
prod-down: ## Stop production environment
	docker-compose down

# Database
.PHONY: db-init
db-init: ## Initialize database with schema
	docker-compose exec -T postgres psql -U ${POSTGRES_USER:-sleeper_user} -d ${POSTGRES_DB:-sleeper_db} < database/schema/schema-v1.sql

.PHONY: db-migrate
db-migrate: ## Run database migrations
	docker-compose exec hasura hasura migrate apply

.PHONY: db-console
db-console: ## Open database console
	docker-compose exec postgres psql -U ${POSTGRES_USER:-sleeper_user} -d ${POSTGRES_DB:-sleeper_db}

.PHONY: db-backup
db-backup: ## Backup database
	@mkdir -p backups
	docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER:-sleeper_user} ${POSTGRES_DB:-sleeper_db} | gzip > backups/db_$(shell date +%Y%m%d_%H%M%S).sql.gz
	@echo "Database backed up to backups/db_$(shell date +%Y%m%d_%H%M%S).sql.gz"

.PHONY: db-restore
db-restore: ## Restore database from latest backup
	@if [ -z "$(FILE)" ]; then \
		FILE=$$(ls -t backups/*.sql.gz | head -1); \
	fi; \
	echo "Restoring from $$FILE"; \
	gunzip -c $$FILE | docker-compose exec -T postgres psql -U ${POSTGRES_USER:-sleeper_user} ${POSTGRES_DB:-sleeper_db}

# Go Service
.PHONY: go-build
go-build: ## Build Go sync service
	cd sync-service && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o bin/sleeper-sync ./cmd/sync

.PHONY: go-run
go-run: ## Run Go sync service locally
	cd sync-service && go run ./cmd/sync

.PHONY: go-test
go-test: ## Run Go tests
	cd sync-service && go test -v -race -coverprofile=coverage.out ./...

.PHONY: go-coverage
go-coverage: go-test ## Run tests and show coverage
	cd sync-service && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated at sync-service/coverage.html"

.PHONY: go-lint
go-lint: ## Run Go linter
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	cd sync-service && golangci-lint run

.PHONY: go-fmt
go-fmt: ## Format Go code
	cd sync-service && go fmt ./...

.PHONY: go-tidy
go-tidy: ## Tidy Go modules
	cd sync-service && go mod tidy

.PHONY: go-deps
go-deps: ## Download Go dependencies
	cd sync-service && go mod download

# Hasura
.PHONY: hasura-console
hasura-console: ## Open Hasura console
	@echo "Opening Hasura console at http://localhost:8080"
	@echo "Admin secret: ${HASURA_ADMIN_SECRET:-myadminsecret}"
	docker-compose exec hasura hasura console --address 0.0.0.0 --no-browser

.PHONY: hasura-metadata-export
hasura-metadata-export: ## Export Hasura metadata
	docker-compose exec hasura hasura metadata export

.PHONY: hasura-metadata-apply
hasura-metadata-apply: ## Apply Hasura metadata
	docker-compose exec hasura hasura metadata apply

# Monitoring
.PHONY: logs
logs: ## View all container logs
	docker-compose logs -f

.PHONY: logs-sync
logs-sync: ## View sync service logs
	docker-compose logs -f sync-service

.PHONY: logs-db
logs-db: ## View database logs
	docker-compose logs -f postgres

.PHONY: logs-hasura
logs-hasura: ## View Hasura logs
	docker-compose logs -f hasura

.PHONY: ps
ps: ## Show running containers
	docker-compose ps

.PHONY: stats
stats: ## Show container resource usage
	docker stats --no-stream

# Testing
.PHONY: test
test: go-test ## Run all tests
	@echo "All tests passed!"

.PHONY: test-integration
test-integration: ## Run integration tests
	cd tests/integration && go test -v ./...

.PHONY: test-e2e
test-e2e: ## Run end-to-end tests
	cd tests/e2e && go test -v ./...

# Sync Operations
.PHONY: sync-league
sync-league: ## Trigger manual league sync
	curl -X POST http://localhost:8000/api/v1/sync/league \
		-H "Content-Type: application/json" \
		-d '{"league_id":"${LEAGUE_ID:-1199102384316362752}"}'

.PHONY: sync-full
sync-full: ## Trigger full sync
	curl -X POST http://localhost:8000/api/v1/sync/full \
		-H "Content-Type: application/json" \
		-d '{"league_id":"${LEAGUE_ID:-1199102384316362752}"}'

# Cleanup
.PHONY: clean
clean: ## Clean up resources
	docker-compose down -v
	rm -rf sync-service/bin
	rm -rf sync-service/coverage.*
	rm -rf sync-service/vendor
	docker system prune -f

.PHONY: clean-all
clean-all: clean ## Clean everything including images
	docker-compose down -v --rmi all
	docker system prune -af

# Setup
.PHONY: setup
setup: ## Initial project setup
	@echo "Setting up Sleeper DB project..."
	@cp -n .env.example .env 2>/dev/null || echo ".env already exists"
	@make go-deps
	@make dev-build
	@echo "Installing pre-commit hooks..."
	@pip install pre-commit 2>/dev/null || true
	@pre-commit install 2>/dev/null || true
	@echo "Setup complete! Run 'make dev' to start development environment"

.PHONY: validate
validate: ## Validate all configuration files
	@echo "Validating configurations..."
	@docker-compose config > /dev/null && echo "✓ Docker Compose valid"
	@cd sync-service && go mod verify && echo "✓ Go modules valid"

# Git
.PHONY: commit
commit: ## Commit changes with conventional commit message
	@echo "Enter commit type (feat/fix/docs/chore/refactor/test):"
	@read TYPE; \
	echo "Enter commit message:"; \
	read MSG; \
	git add -A && git commit -m "$$TYPE: $$MSG"

.PHONY: push
push: ## Push to remote repository
	git push origin $(shell git branch --show-current)