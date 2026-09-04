#!/usr/bin/env bash
# set -e

# Load .env if present
if [ -f .env ]; then
  # Export S3 variables without overriding existing environment
  export $(grep -E '^(S3_|GARAGE_)' .env 2>/dev/null | xargs -0 2>/dev/null || grep -E '^(S3_|GARAGE_)' .env 2>/dev/null)
fi

CONTAINER_NAME="${GARAGE_CONTAINER_NAME:-dev-rexone-core-garage}"
BUCKET_NAME="${S3_BUCKET:-rexone}"
KEY_NAME="rexone-key"

# Auto-initialize cluster layout, bucket, and access keys in background once server is up
(
  for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" /garage status >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  # 1. Initialize cluster layout if no role assigned
  STATUS=$(docker exec "$CONTAINER_NAME" /garage status 2>/dev/null || true)
  if echo "$STATUS" | grep -q "NO ROLE ASSIGNED"; then
    NODE_ID=$(echo "$STATUS" | grep "NO ROLE ASSIGNED" | awk '{print $1}')
    echo "[Garage Init] Assigning cluster layout for node $NODE_ID..."
    docker exec "$CONTAINER_NAME" /garage layout assign -z dc1 -c 1G "$NODE_ID" >/dev/null 2>&1
    docker exec "$CONTAINER_NAME" /garage layout apply --version 1 >/dev/null 2>&1
  fi

  # 2. Create default bucket if missing
  if ! docker exec "$CONTAINER_NAME" /garage bucket info "$BUCKET_NAME" >/dev/null 2>&1; then
    echo "[Garage Init] Creating default bucket '$BUCKET_NAME'..."
    docker exec "$CONTAINER_NAME" /garage bucket create "$BUCKET_NAME" >/dev/null 2>&1
  fi

  # 3. Create or import API key
  if ! docker exec "$CONTAINER_NAME" /garage key info "$KEY_NAME" >/dev/null 2>&1; then
    if [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then
      echo "[Garage Init] Importing API key '$KEY_NAME' from environment..."
      docker exec "$CONTAINER_NAME" /garage key import -n "$KEY_NAME" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" --yes >/dev/null 2>&1
    else
      echo "[Garage Init] Generating new S3 API key '$KEY_NAME'..."
      KEY_OUTPUT=$(docker exec "$CONTAINER_NAME" /garage key create "$KEY_NAME" 2>/dev/null || true)
      GEN_KEY=$(echo "$KEY_OUTPUT" | grep "Key ID:" | awk '{print $3}')
      GEN_SECRET=$(echo "$KEY_OUTPUT" | grep "Secret key:" | awk '{print $3}')

      if [ -n "$GEN_KEY" ] && [ -n "$GEN_SECRET" ]; then
        echo "------------------------------------------------------------------"
        echo "[Garage Key Generated] Copy and paste these into your .env file:"
        echo "S3_ACCESS_KEY=$GEN_KEY"
        echo "S3_SECRET_KEY=$GEN_SECRET"
        echo "------------------------------------------------------------------"
      fi
    fi
    docker exec "$CONTAINER_NAME" /garage bucket allow --read --write --owner "$BUCKET_NAME" --key "$KEY_NAME" >/dev/null 2>&1
  fi

  echo "==> Garage S3 is ready!"
  echo "    S3 Endpoint:     http://localhost:3100"
  echo "    Admin Endpoint:  http://localhost:3101"
  echo "    Default Bucket:  $BUCKET_NAME"
) &

docker compose -f docker-compose.dev.yaml up garage
