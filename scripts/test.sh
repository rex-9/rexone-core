#!/bin/sh

# # Entire suite
# ./scripts/test.sh

# # Directory
# ./scripts/test.sh spec/models

# # Specific file
# ./scripts/test.sh spec/models/user_spec.rb

# # Specific example
# ./scripts/test.sh spec/models/user_spec.rb:42

# # Reproduce a seed
# ./scripts/test.sh --seed 12345

# # Help
# ./scripts/test.sh --help

set -u

COMPOSE_FILE="docker-compose.dev.yaml"
SERVICE="api"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  printf '%s\n' \
    "Usage: ./scripts/test.sh [RSpec paths and options]" \
    "" \
    "Examples:" \
    "  ./scripts/test.sh" \
    "  ./scripts/test.sh spec/models" \
    "  ./scripts/test.sh spec/models/user_spec.rb:42" \
    "  ./scripts/test.sh --seed 12345" \
    "  ./scripts/test.sh --only-failures"
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

if [ "$#" -eq 0 ]; then
  set -- spec
fi

printf '%s\n' "Running specs in the API container (RAILS_ENV=test)..."
docker compose -f "$COMPOSE_FILE" exec -e RAILS_ENV=test "$SERVICE" \
  bundle exec rspec "$@"
