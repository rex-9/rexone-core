#!/bin/bash

# Generate the swagger documentation
docker-compose exec api rake rswag:specs:swaggerize