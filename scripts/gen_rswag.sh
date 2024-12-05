#!/bin/bash

# Generate the swagger documentation
docker-compose -f docker-compose.dev.yaml exec api rake rswag:specs:swaggerize