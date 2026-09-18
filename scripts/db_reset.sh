#!/usr/bin/env bash
# ==============================================================================
# RexOne Core — Development Database Reset Script
#
# Usage:
#   ./scripts/db_reset.sh [-y|--force]
#
# ⚠️ WARNING: Strictly intended for local development.
# Drops, recreates, migrates, and seeds the development database.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

FORCE=false
for arg in "$@"; do
  case "$arg" in
    -y|--force|-f)
      FORCE=true
      ;;
    -h|--help)
      echo "Usage: ./scripts/db_reset.sh [-y|--force]"
      echo "Resets the local development database (drop, create, migrate, seed)."
      exit 0
      ;;
  esac
done

TARGET_ENV="${RAILS_ENV:-development}"

echo ""
echo "=================================================================="
echo " ⚠️  REXONE DEVELOPMENT DATABASE RESET"
echo " Target Environment: $TARGET_ENV"
echo "=================================================================="
echo " This will DROP, RECREATE, MIGRATE, and SEED the database."
echo " All existing local data in '$TARGET_ENV' will be PERMANENTLY LOST."
echo "=================================================================="
echo ""

if [ "$FORCE" = false ]; then
  read -r -p "Are you sure you want to proceed? [y/N]: " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY])
      echo "Proceeding with database reset..."
      ;;
    *)
      echo "Aborted by user. No changes were made."
      exit 0
      ;;
  esac
fi

echo "--> [1/4] Dropping database ($TARGET_ENV)..."
rm -rf db/schema.rb
docker compose -f docker-compose.dev.yaml exec -e RAILS_ENV="$TARGET_ENV" api rails db:drop || true

echo "--> [2/4] Creating new database ($TARGET_ENV)..."
docker compose -f docker-compose.dev.yaml exec -e RAILS_ENV="$TARGET_ENV" api rails db:create

echo "--> [3/4] Running migrations ($TARGET_ENV)..."
docker compose -f docker-compose.dev.yaml exec -e RAILS_ENV="$TARGET_ENV" api rails db:migrate

echo "--> [4/4] Seeding database ($TARGET_ENV)..."
docker compose -f docker-compose.dev.yaml exec -e RAILS_ENV="$TARGET_ENV" api rails db:seed

echo ""
echo "✅ Database successfully reset and seeded for $TARGET_ENV!"
