#!/bin/sh

set -u

COMPOSE_FILE="docker-compose.dev.yaml"
SERVICE="api"

if ! docker info >/dev/null 2>&1; then
  printf '%s\n' "Docker is not running. Start Docker and try again." >&2
  exit 1
fi

if [ -z "$(docker compose -f "$COMPOSE_FILE" ps --status running -q "$SERVICE")" ]; then
  printf '%s\n' "Starting the API and its dependencies..."
  docker compose -f "$COMPOSE_FILE" up -d "$SERVICE" || exit $?
fi

printf '%s\n' \
  "Watching specs in the API container (RAILS_ENV=test)..." \
  "Guard commands: press Enter for help, type 'all' for the full suite, Ctrl-D to stop."

docker compose -f "$COMPOSE_FILE" exec -e RAILS_ENV=test "$SERVICE" \
  bundle exec guard "$@"
