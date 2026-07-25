#!/bin/bash

echo "🧹 Cleaning Docker resources..."
docker system prune -f
docker volume prune -f
docker image prune -f
echo "✅ Done"