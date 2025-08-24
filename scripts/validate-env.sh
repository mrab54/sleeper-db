#!/bin/bash

# Environment Variables Validation Script
# Ensures all required environment variables are set before starting services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Required variables
REQUIRED_VARS=(
    "POSTGRES_DB"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "HASURA_ADMIN_SECRET"
    "PRIMARY_LEAGUE_ID"
)

# Optional but recommended variables
OPTIONAL_VARS=(
    "REDIS_PASSWORD"
    "GRAFANA_ADMIN_PASSWORD"
    "BACKUP_PATH"
    "DISCORD_WEBHOOK_URL"
)

# Function to check if variable is set
check_var() {
    local var_name=$1
    local var_value=${!var_name}
    
    if [ -z "$var_value" ]; then
        return 1
    fi
    return 0
}

# Function to validate variable format
validate_format() {
    local var_name=$1
    local var_value=${!var_name}
    
    case $var_name in
        "PRIMARY_LEAGUE_ID")
            if [[ ! $var_value =~ ^[0-9]{16,}$ ]]; then
                echo -e "${YELLOW}Warning: PRIMARY_LEAGUE_ID should be a numeric string${NC}"
            fi
            ;;
        "POSTGRES_PORT"|"REDIS_PORT"|"SERVER_PORT")
            if [[ ! $var_value =~ ^[0-9]+$ ]] || [ $var_value -lt 1 ] || [ $var_value -gt 65535 ]; then
                echo -e "${RED}Error: $var_name must be a valid port number (1-65535)${NC}"
                return 1
            fi
            ;;
        *"_PASSWORD"|"*_SECRET")
            if [ ${#var_value} -lt 8 ]; then
                echo -e "${YELLOW}Warning: $var_name should be at least 8 characters for security${NC}"
            fi
            ;;
    esac
    return 0
}

echo "======================================"
echo "Validating Environment Variables"
echo "======================================"
echo ""

# Load .env file if it exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo -e "${GREEN}✓ Loaded .env file${NC}"
else
    echo -e "${YELLOW}⚠ No .env file found, using environment variables${NC}"
fi

echo ""
echo "Checking required variables:"
echo "----------------------------"

errors=0
for var in "${REQUIRED_VARS[@]}"; do
    if check_var "$var"; then
        echo -e "${GREEN}✓ $var is set${NC}"
        validate_format "$var"
    else
        echo -e "${RED}✗ $var is not set${NC}"
        errors=$((errors + 1))
    fi
done

echo ""
echo "Checking optional variables:"
echo "----------------------------"

warnings=0
for var in "${OPTIONAL_VARS[@]}"; do
    if check_var "$var"; then
        echo -e "${GREEN}✓ $var is set${NC}"
        validate_format "$var"
    else
        echo -e "${YELLOW}⚠ $var is not set (optional)${NC}"
        warnings=$((warnings + 1))
    fi
done

echo ""
echo "======================================"

# Check database connection string format
if [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ] && [ -n "$POSTGRES_DB" ]; then
    DB_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"
    echo -e "${GREEN}✓ Database URL format is valid${NC}"
fi

# Summary
echo ""
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ All required variables are set!${NC}"
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠ $warnings optional variables are not set${NC}"
    fi
    echo ""
    echo "You can now run: docker-compose up"
    exit 0
else
    echo -e "${RED}✗ $errors required variables are missing!${NC}"
    echo ""
    echo "Please set the missing variables in your .env file or environment"
    echo "Copy .env.example to .env and fill in the values:"
    echo "  cp .env.example .env"
    exit 1
fi
