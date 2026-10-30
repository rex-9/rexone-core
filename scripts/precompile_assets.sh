#!/usr/bin/env bash
set -euo pipefail

# Clean stale precompiled assets, compile fresh assets, and restart the API server
# so Sprockets manifest and Administrate initializers reload in memory.
docker compose -f docker-compose.dev.yaml exec api rails assets:clobber assets:precompile "$@"
docker compose -f docker-compose.dev.yaml restart api
