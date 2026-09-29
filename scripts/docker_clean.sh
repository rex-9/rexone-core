#!/usr/bin/env bash
# ==============================================================================
# RexOne Core — Docker System & Resource Cleanup Script
#
# Usage:
#   ./scripts/docker_clean.sh [-y|--force] [--volumes]
#
# Safeguards:
#   - Detects stopped or restarting core RexOne containers (api, waka, db, media, garage)
#   - Halts and prompts with default [N] if critical containers are not running
#   - NEVER prunes volumes by default; requires explicit '--volumes' flag
# ==============================================================================

set -euo pipefail

FORCE=false
PRUNE_VOLUMES=false

for arg in "$@"; do
  case "$arg" in
    -y|--force|-f)
      FORCE=true
      ;;
    --volumes)
      PRUNE_VOLUMES=true
      ;;
    -h|--help)
      echo "Usage: ./scripts/docker_clean.sh [-y|--force] [--volumes]"
      echo ""
      echo "Flags:"
      echo "  -y, --force    Bypass confirmation prompts (except volume safety checks)"
      echo "  --volumes      Explicitly prune unused volumes (WARNING: destroys data if db is stopped)"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
  esac
done

echo ""
echo "=================================================================="
echo " 🛡️  REXONE DOCKER SYSTEM CLEANUP"
echo "=================================================================="

# 1. Detect if any core containers are stopped or restarting
CORE_CONTAINER_PATTERNS=("rexone.*api" "rexone.*waka" "rexone.*db" "rexone.*media" "rexone.*garage" "postgres")
STOPPED_CONTAINERS=()

if command -v docker >/dev/null 2>&1; then
  for pattern in "${CORE_CONTAINER_PATTERNS[@]}"; do
    MATCHES=$(docker ps -a --filter "status=exited" --filter "status=dead" --filter "status=restarting" --format "{{.Names}} ({{.Status}})" | grep -E "$pattern" || true)
    if [ -n "$MATCHES" ]; then
      while IFS= read -r match; do
        [ -n "$match" ] && STOPPED_CONTAINERS+=("$match")
      done <<< "$MATCHES"
    fi
  done
fi

if [ ${#STOPPED_CONTAINERS[@]} -gt 0 ]; then
  echo ""
  echo " ⚠️  WARNING: Detected stopped or restarting core RexOne containers:"
  for c in "${STOPPED_CONTAINERS[@]}"; do
    echo "    - $c"
  done
  echo ""
  echo " If you continue, Docker cleanup may remove stopped containers or leave"
  echo " their data detached and vulnerable."
  echo ""
  read -r -p " Do you still want to proceed with Docker cleanup? [y/N]: " STOPPED_CONFIRM
  case "$STOPPED_CONFIRM" in
    [yY][eE][sS]|[yY])
      echo " Continuing as requested..."
      ;;
    *)
      echo " Aborted by user to protect stopped containers. Exiting."
      exit 0
      ;;
  esac
fi

# 2. General cleanup prompt
if [ "$FORCE" = false ]; then
  ALL_STOPPED=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "  - {{.Names}} (Status: {{.Status}})" || true)
  RUNNING_NOW=$(docker ps --format "  + {{.Names}} (Status: {{.Status}})" || true)
  DANGLING_COUNT=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ' || echo "0")

  echo ""
  echo "📋 PRE-CLEANUP MANIFEST: Specifically what will be cleaned vs protected"
  echo "──────────────────────────────────────────────────────────────────"
  echo "🗑️  RESOURCES THAT WILL BE CLEANED AND REMOVED AFTER CONFIRMING YES:"
  echo ""
  echo " 1. Stopped / Exited Containers (WILL BE DELETED):"
  if [ -n "$ALL_STOPPED" ]; then
    echo "$ALL_STOPPED"
  else
    echo "    (None - no stopped containers found)"
  fi
  echo ""
  echo " 2. Unused Docker Networks (WILL BE PRUNED):"
  echo "    - All networks not actively attached to a running container"
  echo ""
  echo " 3. Dangling Docker Images (WILL BE PRUNED):"
  echo "    - ${DANGLING_COUNT} untagged/dangling intermediate image layers"
  echo ""
  echo " 4. Docker BuildKit Build Cache (WILL BE PURGED):"
  echo "    - All BuildKit build cache across previous container builds"
  echo ""
  if [ "$PRUNE_VOLUMES" = true ]; then
    echo " 🚨 WARNING: '--volumes' flag is ENABLED. All unattached volumes WILL BE REMOVED."
  else
    echo " 🔒 Volumes are SAFE and will NOT be touched (database & S3 preserved)."
  fi
  echo "──────────────────────────────────────────────────────────────────"
  echo "🔒 RESOURCES THAT WILL STAY SAFE & 100% UNTOUCHED:"
  echo ""
  echo " 🛡️  Active Running Containers (WILL NOT BE KILLED OR STOPPED):"
  if [ -n "$RUNNING_NOW" ]; then
    echo "$RUNNING_NOW"
  else
    echo "    (No containers currently running)"
  fi
  echo "──────────────────────────────────────────────────────────────────"
  echo ""
  read -r -p " Proceed with Docker cleanup and removal of the items listed above? [y/N]: " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY])
      echo " Confirmation received. Proceeding with Docker cleanup..."
      ;;
    *)
      echo " Aborted by user. No resources were pruned."
      exit 0
      ;;
  esac
fi

echo ""
echo "🧹 [1/4] Pruning stopped containers & unused networks..."
docker container prune -f
docker network prune -f

echo "🧹 [2/4] Pruning dangling Docker images..."
docker image prune -f

echo "🧹 [3/4] Pruning Docker build cache..."
docker builder prune -a -f

if [ "$PRUNE_VOLUMES" = true ]; then
  echo ""
  echo "🚨 [4/4] Pruning unused Docker volumes (--volumes specified)..."
  read -r -p " Are you ABSOLUTELY sure you want to prune volumes? [y/N]: " VOL_CONFIRM
  case "$VOL_CONFIRM" in
    [yY][eE][sS]|[yY])
      docker volume prune -f
      echo " Volumes pruned."
      ;;
    *)
      echo " Volume prune skipped."
      ;;
  esac
else
  echo "🔒 [4/4] Volumes preserved (pass '--volumes' to prune volumes)."
fi

echo ""
echo "✅ Docker cleanup complete!"