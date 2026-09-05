#!/bin/bash
# scripts/backup_db.sh — Automated PostgreSQL Database Backup Script
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups/db}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

CONTAINER_NAME="${DB_CONTAINER_NAME:-dev-rexone-core-db}"
DB_USER="${PG_USER:-postgres}"

mkdir -p "${BACKUP_DIR}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  if docker ps --format '{{.Names}}' | grep -q "rexone-core-db"; then
    CONTAINER_NAME="rexone-core-db"
  else
    echo "❌ Error: Database container '${CONTAINER_NAME}' is not running."
    exit 1
  fi
fi

if [ -z "${PG_DATABASE:-}" ]; then
  if docker exec "${CONTAINER_NAME}" psql -U "${DB_USER}" -lqt | cut -d \| -f 1 | grep -qw "rexone_core_production"; then
    DB_NAME="rexone_core_production"
  else
    DB_NAME="rexone_core_development"
  fi
else
  DB_NAME="${PG_DATABASE}"
fi

BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "📦 [DB Backup] Starting PostgreSQL dump for database '${DB_NAME}' from '${CONTAINER_NAME}'..."
docker exec "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists --no-owner --no-privileges | gzip > "${BACKUP_FILE}"

BACKUP_SIZE="$(du -h "${BACKUP_FILE}" | cut -f1)"
echo "✅ [DB Backup] Successfully created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Prune backups older than RETENTION_DAYS
echo "🧹 [DB Backup] Pruning backups older than ${RETENTION_DAYS} days in ${BACKUP_DIR}..."
find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -type f -mtime "+${RETENTION_DAYS}" -delete
echo "✨ [DB Backup] Complete."
