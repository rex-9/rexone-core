#!/usr/bin/env bash
# ==============================================================================
# RexOne — Safe VPS Production Maintenance & Cleanup Script (Coolify Compatible)
#
# Usage:
#   ./scripts/vps_cleanup.sh [-y|--yes|--force]
#
# Flags:
#   -y, --yes, -f, --force   Bypass interactive confirmation prompts (for cron automation)
#   -h, --help               Display this help message
#
# Environment Variables (Configurable):
#   IMAGE_RETENTION_HOURS       Retention window for old images (default: 168 = 7 days)
#   BUILD_CACHE_RETENTION_HOURS Retention window for build cache (default: 168 = 7 days)
#
# Recommended Cron Setup (runs every Sunday at 03:00 UTC):
#   0 3 * * 0 /path/to/rexone-core/scripts/vps_cleanup.sh -y >> /var/log/rexone_vps_cleanup.log 2>&1
#
# Safety Guarantees:
#   - NEVER runs 'docker volume prune'. Persistent database and S3 data remain 100% untouched.
#   - Running containers are NEVER stopped or killed.
#   - Prunes only exited/dead containers, unused images > RETENTION_HOURS, and build cache > RETENTION_HOURS.
# ==============================================================================

set -euo pipefail

FORCE=false

for arg in "$@"; do
  case "$arg" in
    -y|--yes|-f|--force)
      FORCE=true
      ;;
    -h|--help)
      echo "Usage: ./scripts/vps_cleanup.sh [-y|--yes|--force]"
      echo ""
      echo "Flags:"
      echo "  -y, --yes, -f, --force    Bypass interactive confirmation prompt (required for crontab)"
      echo "  -h, --help                Show this help message"
      exit 0
      ;;
  esac
done

# Automatically load .env if present in current or project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/.env" ]; then
  # shellcheck disable=SC1091
  set -a
  source "${PROJECT_ROOT}/.env" 2>/dev/null || true
  set +a
elif [ -f ".env" ]; then
  # shellcheck disable=SC1091
  set -a
  source ".env" 2>/dev/null || true
  set +a
fi

IMAGE_RETENTION_HOURS="${IMAGE_RETENTION_HOURS:-168}"
BUILD_CACHE_RETENTION_HOURS="${BUILD_CACHE_RETENTION_HOURS:-168}"

echo "=================================================================="
echo " [$(date -u '+%Y-%m-%d %H:%M:%S UTC')] RexOne VPS Maintenance & Disk Protection"
echo " Image Retention:       ${IMAGE_RETENTION_HOURS}h (=$(( IMAGE_RETENTION_HOURS / 24 )) days)"
echo " Build Cache Retention: ${BUILD_CACHE_RETENTION_HOURS}h (=$(( BUILD_CACHE_RETENTION_HOURS / 24 )) days)"
echo "=================================================================="

# Check Docker daemon availability
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Error: Docker is not installed or not in PATH."
  exit 1
fi

# Gather container state for manifest
STOPPED_CONTAINERS=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "  - {{.Names}} (ID: {{.ID}}, Status: {{.Status}})" || true)
RUNNING_CONTAINERS=$(docker ps --format "  + {{.Names}} (ID: {{.ID}}, Status: {{.Status}})" || true)

# Interactive pre-execution manifest
if [ "$FORCE" = false ]; then
  echo ""
  echo "📋 PRE-CLEANUP MANIFEST: Specifically what will be cleaned vs protected"
  echo "──────────────────────────────────────────────────────────────────"
  echo "🗑️  RESOURCES THAT WILL BE CLEANED AND REMOVED AFTER CONFIRMING YES:"
  echo ""
  echo " 1. Dead & Exited Containers (WILL BE DELETED):"
  if [ -n "$STOPPED_CONTAINERS" ]; then
    echo "$STOPPED_CONTAINERS"
  else
    echo "    (None found - all clean)"
  fi
  echo ""
  echo " 2. Old Deployment Images (WILL BE PRUNED):"
  echo "    - All unused/unreferenced Docker images older than ${IMAGE_RETENTION_HOURS}h (7 days)"
  echo ""
  echo " 3. Docker BuildKit Build Cache (WILL BE PRUNED):"
  echo "    - All dangling and tagged intermediate BuildKit layers older than ${BUILD_CACHE_RETENTION_HOURS}h (7 days)"
  echo ""
  echo "──────────────────────────────────────────────────────────────────"
  echo "🔒 RESOURCES THAT WILL STAY SAFE & 100% UNTOUCHED:"
  echo ""
  echo " 🛡️  Active Running Containers (WILL NOT BE KILLED OR STOPPED):"
  if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "$RUNNING_CONTAINERS"
  else
    echo "    (No containers currently running)"
  fi
  echo ""
  echo " 🛡️  Persistent Volumes (WILL NEVER BE PRUNED OR TOUCHED):"
  echo "    + Database volumes (e.g. prod-rexone-postgres-data)"
  echo "    + Garage S3 storage volumes (e.g. rexone-garage-meta, rexone-garage-data)"
  echo "──────────────────────────────────────────────────────────────────"
  echo ""

  read -r -p " Proceed with VPS cleanup and removal of the items listed above? [y/N]: " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY])
      echo " Confirmation received. Proceeding with cleanup..."
      ;;
    *)
      echo " Aborted by user. No containers, images, or build cache were removed."
      exit 0
      ;;
  esac
fi

# 1. Prune stopped containers (safe: only dead/exited containers)
echo ""
echo "🧹 [1/3] Pruning dead/exited containers..."
docker container prune -f

# 2. Prune old deployment images older than retention period
echo "🧹 [2/3] Pruning unused images older than ${IMAGE_RETENTION_HOURS}h..."
docker image prune -a --filter "until=${IMAGE_RETENTION_HOURS}h" -f

# 3. Prune old build cache older than retention period (use -a to include non-dangling tagged layers)
echo "🧹 [3/3] Pruning Docker build cache older than ${BUILD_CACHE_RETENTION_HOURS}h..."
docker builder prune -a --filter "until=${BUILD_CACHE_RETENTION_HOURS}h" -f

echo ""
echo "🔒 Persistent volumes were 100% untouched."
echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] RexOne VPS Maintenance finished successfully!"
echo "=================================================================="
