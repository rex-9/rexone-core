#!/bin/bash

# Drop the database
docker-compose exec web rails db:drop

# Create a new database
docker-compose exec web rails db:create

# Run migrations to create new tables
docker-compose exec web rails db:migrate

# Seed the database (optional)
docker-compose exec web rails db:seed
