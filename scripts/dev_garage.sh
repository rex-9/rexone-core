#!/usr/bin/env bash
set -euo pipefail

# Load .env if present
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

CONTAINER_NAME="${GARAGE_CONTAINER_NAME:-dev-rexone-core-garage}"
BUCKET_NAME="${S3_BUCKET:-rexone}"
KEY_NAME="rexone-key"

S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

docker compose -f docker-compose.dev.yaml up -d garage

for _attempt in {1..30}; do
  if docker exec "$CONTAINER_NAME" /garage status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker exec "$CONTAINER_NAME" /garage status >/dev/null 2>&1; then
  echo "[Garage Init] Garage did not become ready within 30 seconds." >&2
  exit 1
fi

# 1. Initialize cluster layout if no role assigned
STATUS=$(docker exec "$CONTAINER_NAME" /garage status)
if echo "$STATUS" | grep -q "NO ROLE ASSIGNED"; then
  NODE_ID=$(echo "$STATUS" | grep "NO ROLE ASSIGNED" | awk '{print $1}')
  echo "[Garage Init] Assigning cluster layout for node $NODE_ID..."
  docker exec "$CONTAINER_NAME" /garage layout assign -z dc1 -c 1G "$NODE_ID"
  docker exec "$CONTAINER_NAME" /garage layout apply --version 1
fi

# 2. Create default bucket if missing
if ! docker exec "$CONTAINER_NAME" /garage bucket info "$BUCKET_NAME" >/dev/null 2>&1; then
  echo "[Garage Init] Creating default bucket '$BUCKET_NAME'..."
  docker exec "$CONTAINER_NAME" /garage bucket create "$BUCKET_NAME"
fi

# 3. Import a valid configured key, or generate a Garage v1 key pair.
if [[ -n "$S3_ACCESS_KEY" && "$S3_SECRET_KEY" =~ ^[[:xdigit:]]{64}$ ]]; then
  if ! docker exec "$CONTAINER_NAME" /garage key info "$S3_ACCESS_KEY" >/dev/null 2>&1; then
    echo "[Garage Init] Importing configured API key '$KEY_NAME'..."
    docker exec "$CONTAINER_NAME" /garage key import -n "$KEY_NAME" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" --yes
  fi
else
  echo "[Garage Init] Configured credentials are absent or incompatible with Garage v1."
  KEY_OUTPUT=$(docker exec "$CONTAINER_NAME" /garage key create "$KEY_NAME")
  GENERATED_ACCESS_KEY=$(echo "$KEY_OUTPUT" | awk -F': ' '/Key ID:/ { print $2 }')
  GENERATED_SECRET_KEY=$(echo "$KEY_OUTPUT" | awk -F': ' '/Secret key:/ { print $2 }')

  docker exec "$CONTAINER_NAME" /garage bucket allow --read --write --owner "$BUCKET_NAME" --key "$GENERATED_ACCESS_KEY"
  echo "------------------------------------------------------------------"
  echo "[Garage Init] Replace these two values in .env, then restart API and media:"
  echo "S3_ACCESS_KEY=$GENERATED_ACCESS_KEY"
  echo "S3_SECRET_KEY=$GENERATED_SECRET_KEY"
  echo "------------------------------------------------------------------"
  exit 0
fi

docker exec "$CONTAINER_NAME" /garage bucket allow --read --write --owner "$BUCKET_NAME" --key "$S3_ACCESS_KEY"
docker exec "$CONTAINER_NAME" /garage key info "$S3_ACCESS_KEY" >/dev/null

echo "==> Garage S3 is ready!"
echo "    S3 Endpoint:     http://localhost:3100"
echo "    Admin Endpoint:  http://localhost:3101"
echo "    Default Bucket:  $BUCKET_NAME"

docker compose -f docker-compose.dev.yaml logs -f garage
