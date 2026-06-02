#!/bin/bash

# Drop the database
docker-compose -f docker-compose.dev.yaml exec api rails db:drop RAILS_ENV=development

# Create a new database
docker-compose -f docker-compose.dev.yaml exec api rails db:create RAILS_ENV=development

# Run migrations to create new tables
docker-compose -f docker-compose.dev.yaml exec api rails db:migrate RAILS_ENV=development

# Seed the database (optional)
docker-compose -f docker-compose.dev.yaml exec api rails db:seed RAILS_ENV=development