#!/usr/bin/env bash
# ==============================================================================
# RexOne Production Secret Generator
# Generates high-entropy cryptographically secure random keys for .env
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "  🔐 RexOne Production Secret Key Generator"
echo "======================================================================"
echo ""
echo "Copy and paste these values into your production .env file:"
echo ""

SECRET_KEY_BASE=$(openssl rand -hex 64)
JWT_SECRET_KEY=$(openssl rand -hex 32)
GARAGE_ADMIN_TOKEN=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)

echo "# Security & Cryptography"
echo "RAILS_SECRET_KEY_BASE=${SECRET_KEY_BASE}"
echo "RAILS_JWT_SECRET_KEY=${JWT_SECRET_KEY}"
echo ""
echo "# Storage Engine"
echo "S3_ADMIN_TOKEN=${GARAGE_ADMIN_TOKEN}"
echo ""
echo "# Database (PostgreSQL)"
echo "PG_PASSWORD=${POSTGRES_PASSWORD}"
echo ""
echo "======================================================================"
echo "  ✅ Generated 4 high-entropy production keys successfully."
echo "======================================================================"
