#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

COMPOSE_FILE="docker-compose.dev.yaml"
MODE="${1:-all}"
DB_STARTED_BY_CI=false
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

if [[ "$MODE" != "all" && "$MODE" != "contracts" ]]; then
  echo "Usage: ./scripts/ci.sh [all|contracts]" >&2
  exit 2
fi

./scripts/check_locales.sh

run_native_ci() {
  bin/rails db:test:prepare

  if [[ "$MODE" == "all" ]]; then
    bin/rails zeitwerk:check
    bundle exec rubocop
  fi

  bundle exec rake rswag:specs:swaggerize

  if [[ "$MODE" == "contracts" ]]; then
    bundle exec rspec spec/openapi spec/channels spec/services/socket_service
  else
    bundle exec rspec --tag ~type:system --tag ~e2e
  fi
}

# GitHub Actions provides Ruby, cached gems, and PostgreSQL directly. Local
# development keeps using Compose for parity with the application stack.
if [[ "${CI:-false}" == "true" ]]; then
  run_native_ci
  exit 0
fi

[[ -f .env ]] || cp .env.example .env

cleanup() {
  if [[ "$DB_STARTED_BY_CI" == "true" ]]; then
    docker compose -f "$COMPOSE_FILE" stop db >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker compose -f "$COMPOSE_FILE" build api

if [[ -z "$(docker compose -f "$COMPOSE_FILE" ps --status running -q db)" ]]; then
  docker compose -f "$COMPOSE_FILE" up -d --wait db
  DB_STARTED_BY_CI=true
fi

if [[ "$MODE" == "contracts" ]]; then
  TEST_COMMAND="bin/rails db:test:prepare && bundle exec rake rswag:specs:swaggerize && bundle exec rspec spec/openapi spec/channels spec/services/socket_service"
else
  TEST_COMMAND="bin/rails db:test:prepare && bin/rails zeitwerk:check && bundle exec rubocop && bundle exec rake rswag:specs:swaggerize && bundle exec rspec --tag ~type:system --tag ~e2e"
fi

docker compose -f "$COMPOSE_FILE" run --rm -T \
  --user "$HOST_UID:$HOST_GID" \
  -e HOME=/tmp \
  -e RAILS_ENV=test \
  api \
  sh -c "$TEST_COMMAND"
