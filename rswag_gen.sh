#!/bin/bash

# Generate the swagger documentation
docker-compose exec web rake rswag:specs:swaggerize