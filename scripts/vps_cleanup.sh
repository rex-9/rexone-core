#!/usr/bin/env bash
# ==============================================================================
# RexOne — Safe VPS Production Maintenance & Cleanup Script (Coolify Compatible)
#
# Usage:
#   ./scripts/vps_cleanup.sh
#
# Environment Variables (Configurable):
#   IMAGE_RETENTION_HOURS       Retention window for old images (default: 168 = 7 days)
#   BUILD_CACHE_RETENTION_HOURS Retention window for build cache (default: 168 = 7 days)
#
# Recommended Cron Setup (runs every Sunday at 03:00 UTC):
#   0 3 * * 0 /path/to/rexone-core/scripts/vps_cleanup.sh >> /var/log/rexone_vps_cleanup.log 2>&1
#
# Safety:
#   - NEVER runs 'docker volume prune'. Persistent database and S3 data remain 100% untouched.
#   - Prunes only images and builder cache older than RETENTION_HOURS.
# ==============================================================================

set -euo pipefail

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
echo " [$(date -u '+%Y-%m-%d %H:%M:%S UTC')] Starting RexOne VPS Maintenance"
echo " Image Retention: ${IMAGE_RETENTION_HOURS}h (=$(( IMAGE_RETENTION_HOURS / 24 )) days)"
echo " Build Cache Retention: ${BUILD_CACHE_RETENTION_HOURS}h (=$(( BUILD_CACHE_RETENTION_HOURS / 24 )) days)"
echo "=================================================================="

# 1. Prune stopped containers (safe: only dead/exited containers)
echo "🧹 [1/3] Pruning dead/exited containers..."
docker container prune -f

# 2. Prune old deployment images older than retention period
echo "🧹 [2/3] Pruning unused images older than ${IMAGE_RETENTION_HOURS}h..."
docker image prune -a --filter "until=${IMAGE_RETENTION_HOURS}h" -f

# 3. Prune old build cache older than retention period
echo "🧹 [3/3] Pruning Docker build cache older than ${BUILD_CACHE_RETENTION_HOURS}h..."
docker builder prune --filter "until=${BUILD_CACHE_RETENTION_HOURS}h" -f

echo "🔒 Persistent volumes were untouched."
echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] RexOne VPS Maintenance finished successfully!"
echo "=================================================================="
