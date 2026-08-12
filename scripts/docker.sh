#!/bin/sh

docker-compose -f docker-compose.dev.yaml exec api rails "$@"