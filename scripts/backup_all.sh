#!/bin/bash
# scripts/backup_all.sh — Unified Database & Garage Storage Backup Runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "🛡️  Starting Rexone Full Ecosystem Backup"
echo "=========================================="

"${SCRIPT_DIR}/backup_db.sh"
echo ""
"${SCRIPT_DIR}/backup_garage.sh"

echo ""
echo "=========================================="
echo "🎉 Full Backup Completed Successfully!"
echo "=========================================="
