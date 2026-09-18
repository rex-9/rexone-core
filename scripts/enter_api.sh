#!/usr/bin/env bash
# ==============================================================================
# RexOne Core — Enter API Container Shell / Exec
#
# Usage:
#   ./scripts/enter_api.sh           # Opens interactive bash shell
#   ./scripts/enter_api.sh rails c   # Runs a command inside api container
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [ $# -eq 0 ]; then
  # Default to interactive shell
  docker compose -f docker-compose.dev.yaml exec api bash 2>/dev/null || \
  docker compose -f docker-compose.dev.yaml exec api sh
else
  docker compose -f docker-compose.dev.yaml exec api "$@"
fi