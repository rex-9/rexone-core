#!/bin/bash

# Check if the containers are already running
if [ "$(docker-compose ps -q)" ]; then
  echo "Containers are already running. Starting without rebuild..."
  docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
else
  echo "Containers are not running. Building and starting..."
  docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
fi

# Docker on Production

# docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build

# Script without Docker

# Set the environment variables
# export RAILS_APP_JWT_SECRET_KEY=auth-service
# export RAILS_APP_CLIENT_BASE_URL=http://localhost:5173
# export RAILS_APP_SERVER_BASE_URL=http://localhost:3000

# # Start the server
# rails s