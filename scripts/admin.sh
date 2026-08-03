#!/bin/bash

# Generate the administrate dashboard
docker-compose -f docker-compose.dev.yaml exec api rails generate administrate:install

# docker-compose -f docker-compose.dev.yaml exec api rails generate administrate:install
# docker-compose -f docker-compose.dev.yaml exec api rails generate administrate:dashboard Payment::Product
