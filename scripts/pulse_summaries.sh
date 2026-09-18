#!/usr/bin/env bash

# Backfill Rails Pulse APM summaries
docker compose -f docker-compose.dev.yaml exec api rails rails_pulse:backfill_summaries "$@"

