#!/bin/sh

# # Entire codebase
# ./scripts/lint.sh
#
# # Autocorrect safe offenses
# ./scripts/lint.sh -a
#
# # Autocorrect all offenses (safe + unsafe)
# ./scripts/lint.sh -A
#
# # Specific file or folder
# ./scripts/lint.sh app/models/user.rb
#
# # Help
# ./scripts/lint.sh --help

set -u

# Ensure standard binary paths are in PATH when invoked by GUI git clients
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:${HOME:-}/.docker/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

COMPOSE_FILE="docker-compose.dev.yaml"
SERVICE="api"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  printf '%s\n' \
    "Usage: ./scripts/lint.sh [RuboCop options and file paths]" \
    "" \
    "Examples:" \
    "  ./scripts/lint.sh" \
    "  ./scripts/lint.sh -a" \
    "  ./scripts/lint.sh -A" \
    "  ./scripts/lint.sh app/models/user.rb" \
    "  ./scripts/lint.sh --only Layout/TrailingWhitespace"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  printf '%s\n' "Docker is not running. Start Docker and try again." >&2
  exit 1
fi

if [ -z "$(docker compose -f "$COMPOSE_FILE" ps --status running -q "$SERVICE")" ]; then
  printf '%s\n' "Starting the API and its dependencies..."
  docker compose -f "$COMPOSE_FILE" up -d "$SERVICE" || exit $?
fi

printf '%s\n' "Running RuboCop in the API container..."
docker compose -f "$COMPOSE_FILE" exec "$SERVICE" \
  bundle exec rubocop "$@"
