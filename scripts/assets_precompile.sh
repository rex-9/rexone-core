#!/bin/bash

# Precompile the assets for the administrate dashboards
docker-compose -f docker-compose.dev.yaml exec api rails assets:precompile