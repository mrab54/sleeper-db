#!/bin/bash

# Database Migration Script
# Uses golang-migrate for database migrations

set -e

# Configuration
DB_HOST=${DATABASE_HOST:-localhost}
DB_PORT=${DATABASE_PORT:-5432}
DB_USER=${DATABASE_USER:-sleeper_user}
DB_PASSWORD=${DATABASE_PASSWORD:-sleeper_password}
DB_NAME=${DATABASE_NAME:-sleeper_db}
DB_SSL=${DATABASE_SSL_MODE:-disable}

MIGRATIONS_PATH="./database/migrations"
DB_URL="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSL}&search_path=sleeper"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if migrate is installed
if ! command -v migrate &> /dev/null; then
    echo -e "${YELLOW}migrate not found. Installing...${NC}"
    go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
fi

# Function to run migration
run_migration() {
    local action=$1
    
    case $action in
        "up")
            echo -e "${GREEN}Running migrations up...${NC}"
            migrate -path ${MIGRATIONS_PATH} -database "${DB_URL}" up
            ;;
        "down")
            echo -e "${YELLOW}Rolling back last migration...${NC}"
            migrate -path ${MIGRATIONS_PATH} -database "${DB_URL}" down 1
            ;;
        "drop")
            echo -e "${RED}Dropping all migrations...${NC}"
            read -p "Are you sure? This will delete all data! (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                migrate -path ${MIGRATIONS_PATH} -database "${DB_URL}" drop -f
            fi
            ;;
        "force")
            echo -e "${YELLOW}Forcing migration version...${NC}"
            migrate -path ${MIGRATIONS_PATH} -database "${DB_URL}" force $2
            ;;
        "version")
            echo -e "${GREEN}Current migration version:${NC}"
            migrate -path ${MIGRATIONS_PATH} -database "${DB_URL}" version
            ;;
        "create")
            if [ -z "$2" ]; then
                echo -e "${RED}Please provide a migration name${NC}"
                exit 1
            fi
            echo -e "${GREEN}Creating new migration: $2${NC}"
            migrate create -ext sql -dir ${MIGRATIONS_PATH} -seq $2
            ;;
        *)
            echo "Usage: $0 {up|down|drop|force|version|create} [args]"
            exit 1
            ;;
    esac
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 {up|down|drop|force|version|create} [args]"
    exit 1
fi

run_migration $@

echo -e "${GREEN}Migration completed successfully!${NC}"
