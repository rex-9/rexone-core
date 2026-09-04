#!/bin/bash
# scripts/backup_garage.sh — Automated Garage S3 Storage Backup Script
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups/garage}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/garage_backup_${TIMESTAMP}.tar.gz"

CONTAINER_NAME="${GARAGE_CONTAINER_NAME:-dev-rexone-core-garage}"

mkdir -p "${BACKUP_DIR}"

# 1. Trigger live metadata snapshot if container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "📸 [Garage Backup] Triggering live metadata snapshot on '${CONTAINER_NAME}'..."
  docker exec "${CONTAINER_NAME}" /garage meta snapshot || true
elif docker ps --format '{{.Names}}' | grep -q "rexone-core-garage"; then
  CONTAINER_NAME="rexone-core-garage"
  echo "📸 [Garage Backup] Triggering live metadata snapshot on '${CONTAINER_NAME}'..."
  docker exec "${CONTAINER_NAME}" /garage meta snapshot || true
fi

# 2. Locate Garage meta and data volumes
META_VOL="$(docker volume ls --format '{{.Name}}' | grep 'garage-meta' | head -n 1 || true)"
DATA_VOL="$(docker volume ls --format '{{.Name}}' | grep 'garage-data' | head -n 1 || true)"

if [ -z "${META_VOL}" ] || [ -z "${DATA_VOL}" ]; then
  echo "❌ Error: Could not locate 'garage-meta' and 'garage-data' Docker volumes."
  exit 1
fi

echo "📦 [Garage Backup] Archiving volumes '${META_VOL}' and '${DATA_VOL}'..."
docker run --rm \
  -v "${META_VOL}:/meta:ro" \
  -v "${DATA_VOL}:/data:ro" \
  -v "$(cd "${BACKUP_DIR}" && pwd):/backup" \
  alpine tar -czf "/backup/garage_backup_${TIMESTAMP}.tar.gz" -C / meta data

BACKUP_SIZE="$(du -h "${BACKUP_FILE}" | cut -f1)"
echo "✅ [Garage Backup] Successfully created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# 3. Prune old backups
echo "🧹 [Garage Backup] Pruning backups older than ${RETENTION_DAYS} days in ${BACKUP_DIR}..."
find "${BACKUP_DIR}" -name "garage_backup_*.tar.gz" -type f -mtime "+${RETENTION_DAYS}" -delete
echo "✨ [Garage Backup] Complete."
