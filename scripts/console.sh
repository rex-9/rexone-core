#!/bin/bash
# scripts/rails

# Enter the Rails Console
docker-compose -f docker-compose.dev.yaml exec api rails console