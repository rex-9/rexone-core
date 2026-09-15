#!/usr/bin/env bash
set -e

# Run all Core services (PostgreSQL, Rails 8 API, Solid Queue, Garage S3, Media Worker)
docker compose -f docker-compose.dev.yaml up "$@"
