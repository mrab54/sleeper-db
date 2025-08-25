#!/bin/bash

# Sleeper DB Application Uninstaller
# This script completely removes all Docker containers, volumes, images, and build artifacts

set -e

echo "================================================"
echo "     Sleeper DB Application Uninstaller"
echo "================================================"
echo ""
echo "This script will remove:"
echo "  - All Docker containers (sleeper-*)"
echo "  - All Docker volumes (sleeper-db_*)"
echo "  - All Docker images (sleeper-*, hasura/*, postgres:*, redis:*)"
echo "  - All build artifacts"
echo "  - Docker networks"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Starting uninstall process..."
echo ""

# Step 1: Stop and remove containers
echo "1. Stopping and removing containers..."
docker-compose down 2>/dev/null || true

# Remove any remaining sleeper containers
docker ps -a --filter "name=sleeper-" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
echo "   ✓ Containers removed"

# Step 2: Remove volumes
echo ""
echo "2. Removing Docker volumes..."
docker volume ls --filter "name=sleeper-db" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true

# Also remove any volumes created by docker-compose
docker volume ls --format "{{.Name}}" | grep -E "^sleeper-db_" | xargs -r docker volume rm 2>/dev/null || true
echo "   ✓ Volumes removed"

# Step 3: Remove images
echo ""
echo "3. Removing Docker images..."

# Remove locally built images
docker images --filter "reference=sleeper-sync" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
docker images --filter "reference=sleeper-db-sync-service" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true

# Remove downloaded images used by the project
docker images --filter "reference=hasura/graphql-engine" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
docker images --filter "reference=postgres:15-alpine" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
docker images --filter "reference=redis:7-alpine" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true

# Remove any dangling images from builds
docker images -f "dangling=true" -q | xargs -r docker rmi 2>/dev/null || true
echo "   ✓ Images removed"

# Step 4: Remove networks
echo ""
echo "4. Removing Docker networks..."
docker network ls --filter "name=sleeper-db" --format "{{.Name}}" | xargs -r docker network rm 2>/dev/null || true
echo "   ✓ Networks removed"

# Step 5: Clean build artifacts
echo ""
echo "5. Cleaning build artifacts..."

# Clean Go build artifacts
if [ -d "sync-service/vendor" ]; then
    rm -rf sync-service/vendor
    echo "   ✓ Removed vendor directory"
fi

if [ -d "sync-service/bin" ]; then
    rm -rf sync-service/bin
    echo "   ✓ Removed bin directory"
fi

if [ -d "bin" ]; then
    rm -rf bin
    echo "   ✓ Removed root bin directory"
fi

# Clean any Go cache
go clean -cache 2>/dev/null || true
go clean -modcache 2>/dev/null || true

# Step 6: Prune Docker system (optional)
echo ""
read -p "Do you want to run 'docker system prune' to clean up unused Docker resources? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy]es$ ]]; then
    echo "6. Running Docker system prune..."
    docker system prune -f
    echo "   ✓ Docker system pruned"
fi

echo ""
echo "================================================"
echo "     Uninstall Complete!"
echo "================================================"
echo ""
echo "The following items have been removed:"
echo "  ✓ All sleeper-* containers"
echo "  ✓ All sleeper-db volumes and data"
echo "  ✓ All related Docker images"
echo "  ✓ Docker networks"
echo "  ✓ Build artifacts"
echo ""
echo "Your source code and configuration files are still intact."
echo "To reinstall, run: docker-compose up -d --build"
echo ""