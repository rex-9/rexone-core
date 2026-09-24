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
  echo ""
  echo " This will prune stopped containers, unused networks, and dangling images/build cache."
  if [ "$PRUNE_VOLUMES" = true ]; then
    echo " 🚨 WARNING: '--volumes' flag is ENABLED. Unused volumes WILL BE REMOVED."
  else
    echo " 🔒 Volumes are SAFE and will NOT be touched."
  fi
  read -r -p " Proceed with cleanup? [y/N]: " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY])
      echo " Proceeding with Docker cleanup..."
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