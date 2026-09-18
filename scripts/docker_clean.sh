#!/usr/bin/env bash
# ==============================================================================
# RexOne Core — Docker System & Resource Cleanup Script
#
# Usage:
#   ./scripts/docker_clean.sh [-y|--force]
#
# ⚠️ WARNING: Prunes stopped containers AND ALL UNUSED VOLUMES, including
# development PostgreSQL data and Garage S3 data if containers are stopped!
# ==============================================================================

set -euo pipefail

FORCE=false
for arg in "$@"; do
  case "$arg" in
    -y|--force|-f)
      FORCE=true
      ;;
    -h|--help)
      echo "Usage: ./scripts/docker_clean.sh [-y|--force]"
      echo "Prunes unused Docker containers, networks, images, and volumes."
      exit 0
      ;;
  esac
done

echo ""
echo "=================================================================="
echo " ⚠️  REXONE DOCKER SYSTEM CLEANUP"
echo "=================================================================="
echo " This will execute 'docker system prune', 'docker volume prune',"
echo " and 'docker image prune'."
echo ""
echo " 🚨 CAUTION: If containers are currently stopped, volume prune will"
echo " PERMANENTLY ERASE your local PostgreSQL database (dev-rexone-core-db-data)"
echo " and Garage S3 data (garage-meta, garage-data)!"
echo "=================================================================="
echo ""

if [ "$FORCE" = false ]; then
  read -r -p "Are you sure you want to prune Docker resources and volumes? [y/N]: " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY])
      echo "Proceeding with Docker cleanup..."
      ;;
    *)
      echo "Aborted by user. No resources were pruned."
      exit 0
      ;;
  esac
fi

echo "🧹 [1/3] Pruning stopped containers & unused networks..."
docker system prune -f

echo "🧹 [2/3] Pruning unused Docker volumes..."
docker volume prune -f

echo "🧹 [3/3] Pruning dangling Docker images..."
docker image prune -f

echo "✅ Docker cleanup complete!"