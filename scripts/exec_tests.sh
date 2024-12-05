#!/bin/bash

# Execute tests
docker-compose -f docker-compose.dev.yaml exec api bundle exec rspec