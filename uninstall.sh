#!/bin/bash

# Sleeper DB Uninstaller
set -e

echo "================================================"
echo "     Sleeper DB Complete Uninstaller"
echo "================================================"
echo ""
echo "This will remove:"
echo "  - Docker containers (sleeper-*)"
echo "  - Docker volumes (including postgres data)"
echo "  - Docker images (postgres, hasura, docs server)"
echo "  - Docker networks (sleeper-net)"
echo "  - Build artifacts and caches"
echo ""
echo "WARNING: This will DELETE ALL DATA in the database!"
echo ""
read -p "Are you sure you want to remove everything? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo "Starting complete uninstall..."
echo ""

# Stop all containers first
echo "1. Stopping all Sleeper DB containers..."
docker-compose down 2>/dev/null || true
docker stop sleeper-postgres sleeper-hasura sleeper-docs 2>/dev/null || true
echo "   ✓ Done"

# Remove containers
echo "2. Removing containers..."
docker rm -f sleeper-postgres sleeper-hasura sleeper-docs 2>/dev/null || true
echo "   ✓ Done"

# Remove volumes (including data)
echo "3. Removing volumes (INCLUDING ALL DATA)..."
docker volume rm sleeper-db_postgres_data 2>/dev/null || true
docker volume ls | grep sleeper | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true
echo "   ✓ Done"

# Remove network
echo "4. Removing Docker network..."
docker network rm sleeper-db_sleeper-net 2>/dev/null || true
echo "   ✓ Done"

# Remove images
echo "5. Removing Docker images..."
# Remove our custom docs image
docker rmi sleeper-db-docs:latest 2>/dev/null || true
docker rmi $(docker images -q sleeper-db-docs) 2>/dev/null || true

# Remove Hasura image
docker rmi hasura/graphql-engine:v2.36.0 2>/dev/null || true
docker images --filter "reference=hasura/graphql-engine" -q | xargs -r docker rmi -f 2>/dev/null || true

# Remove PostgreSQL image
docker rmi postgres:17-alpine 2>/dev/null || true
docker images --filter "reference=postgres" -q | xargs -r docker rmi -f 2>/dev/null || true

# Remove golang build image if it exists
docker images --filter "reference=golang:1.21-alpine" -q | xargs -r docker rmi 2>/dev/null || true

# Remove alpine base image
docker images --filter "reference=alpine" -q | xargs -r docker rmi 2>/dev/null || true
echo "   ✓ Done"

# Clean up any dangling images and build cache
echo "6. Cleaning up build artifacts and caches..."
docker image prune -f 2>/dev/null || true
docker builder prune -f 2>/dev/null || true
echo "   ✓ Done"

# Clean up unused Docker resources
echo "7. Final cleanup of unused Docker resources..."
docker system prune -f --volumes 2>/dev/null || true
echo "   ✓ Done"

# Check if anything is left
echo ""
echo "Checking for remaining Sleeper DB resources..."
echo ""

# Check for remaining containers
remaining_containers=$(docker ps -a | grep sleeper || true)
if [ ! -z "$remaining_containers" ]; then
    echo "⚠ Warning: Some containers may still exist:"
    echo "$remaining_containers"
fi

# Check for remaining volumes
remaining_volumes=$(docker volume ls | grep sleeper || true)
if [ ! -z "$remaining_volumes" ]; then
    echo "⚠ Warning: Some volumes may still exist:"
    echo "$remaining_volumes"
fi

# Check for remaining images
remaining_images=$(docker images | grep -E "sleeper|hasura|postgres" || true)
if [ ! -z "$remaining_images" ]; then
    echo "⚠ Warning: Some images may still exist:"
    echo "$remaining_images"
fi

echo ""
echo "================================================"
echo "Uninstall complete!"
echo "================================================"
echo ""
echo "All Sleeper DB Docker resources have been removed."
echo "To reinstall, run: docker-compose up"
echo ""
echo "Note: Local files (code, configs, SQL scripts) were NOT deleted."
echo "      Only Docker resources were removed."