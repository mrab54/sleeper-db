#!/bin/bash

# Sleeper DB Uninstaller
set -e

echo "================================================"
echo "     Sleeper DB Uninstaller"
echo "================================================"
echo ""
echo "This will remove:"
echo "  - Docker containers (sleeper-*)"
echo "  - Docker volumes"
echo "  - Docker images"
echo "  - Docker networks"
echo ""
read -p "Are you sure? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo "Uninstalling..."
echo ""

# Stop and remove everything
echo "1. Removing containers and volumes..."
docker-compose down -v 2>/dev/null || true
echo "   ✓ Done"

# Remove images
echo "2. Removing images..."
docker images --filter "reference=hasura/graphql-engine" -q | xargs -r docker rmi 2>/dev/null || true
docker images --filter "reference=postgres:17-alpine" -q | xargs -r docker rmi 2>/dev/null || true
echo "   ✓ Done"

# Clean up
echo "3. Pruning unused Docker resources..."
docker system prune -f
echo "   ✓ Done"

echo ""
echo "Uninstall complete!"
echo "To reinstall, run: docker-compose up -d"