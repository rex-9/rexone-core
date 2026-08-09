#!/bin/bash

# Generate the administrate dashboard
docker-compose -f docker-compose.dev.yaml exec api rails rails_pulse:backfill_summaries
