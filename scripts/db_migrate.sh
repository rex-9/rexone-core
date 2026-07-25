#!/bin/bash
# scripts/db_migrate.sh - Run database migrations inside Docker

docker-compose -f docker-compose.dev.yaml exec api rails db:migrate