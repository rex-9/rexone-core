#!/bin/bash

# Run tests
docker-compose -f docker-compose.dev.yaml exec api bundle exec rspec
# docker-compose -f docker-compose.dev.yaml exec api bundle exec rspec ./spec/models/asset_spec.rb