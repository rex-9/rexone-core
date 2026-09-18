#!/bin/bash
# scripts/rebrand.sh
# Master Rebranding Engine for the RexOne Ecosystem (Core, Web, Mobile)
# Implements Universal Ecosystem Naming Conventions (Single-word & Multi-word)
# Usage: ./scripts/rebrand.sh [path/to/brand.config.json]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$CORE_DIR/.." && pwd)"

CONFIG_FILE="${1:-$CORE_DIR/brand.config.json}"

echo "============================================================"
echo "🏛️  REXONE ECOSYSTEM REBRANDING ENGINE"
echo "============================================================"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: Config file not found at: $CONFIG_FILE"
  echo "Usage: ./scripts/rebrand.sh [brand.config.json]"
  exit 1
fi

echo "📖 Reading brand configuration from: $(basename "$CONFIG_FILE")..."

# Helper to read JSON values via ruby, node, or python3
read_json() {
  ruby -rjson -e "c = JSON.parse(File.read('$CONFIG_FILE')); val = $1; puts val unless val.nil?" 2>/dev/null || \
  node -e "const c = require('$CONFIG_FILE'); const val = $1; if (val !== undefined) console.log(val);" 2>/dev/null || \
  python3 -c "import json; c = json.load(open('$CONFIG_FILE')); val = $1; print(val if val is not None else '')" 2>/dev/null || true
}

BRAND_NAME=$(read_json "c.dig('brand', 'name')")
BRAND_SLUG_RAW=$(read_json "c.dig('brand', 'slug')")
BRAND_SHORT_NAME=$(read_json "c.dig('brand', 'shortName') || c.dig('brand', 'name')")
BRAND_DESC=$(read_json "c.dig('brand', 'description')")
BRAND_LOGO=$(read_json "c.dig('brand', 'logoPath')")

SLUG_SOURCE="${BRAND_SLUG_RAW:-$BRAND_NAME}"

# Derive standardized naming forms per docs/NAMING_CONVENTIONS.md
BRAND_SLUG_KEBAB=$(ruby -e "puts '$SLUG_SOURCE'.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')" 2>/dev/null || \
  node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''))" 2>/dev/null || \
  echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//')

BRAND_SLUG_SNAKE=$(ruby -e "puts '$SLUG_SOURCE'.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')" 2>/dev/null || \
  node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, ''))" 2>/dev/null || \
  echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '_' | sed 's/^_//;s/_$//')

BRAND_SLUG_FLAT=$(ruby -e "puts '$SLUG_SOURCE'.downcase.gsub(/[^a-z0-9]/, '')" 2>/dev/null || \
  node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]/g, ''))" 2>/dev/null || \
  echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')

BRAND_PASCAL=$(ruby -e "puts '$SLUG_SOURCE'.split(/[^a-zA-Z0-9]+/).map(&:capitalize).join" 2>/dev/null || echo "$BRAND_NAME")

MOBILE_APP_NAME=$(read_json "c.dig('mobile', 'appName') || \"${BRAND_NAME} Mobile\"")
MOBILE_PACKAGE=$(read_json "c.dig('mobile', 'packageName') || \"com.rex9.${BRAND_SLUG_FLAT}\"")

WEB_APP_NAME=$(read_json "c.dig('web', 'appName') || \"${BRAND_NAME} Web\"")
WEB_TITLE=$(read_json "c.dig('web', 'title') || \"${BRAND_NAME} — Product Foundation\"")

CORE_APP_NAME=$(read_json "c.dig('core', 'appName') || \"${BRAND_NAME} Core\"")

RESOLVED_LOGO_PATH=""
if [ -n "$BRAND_LOGO" ]; then
  if [ -f "$CORE_DIR/$BRAND_LOGO" ]; then
    RESOLVED_LOGO_PATH="$CORE_DIR/$BRAND_LOGO"
  elif [ -f "$BRAND_LOGO" ]; then
    RESOLVED_LOGO_PATH="$(cd "$(dirname "$BRAND_LOGO")" && pwd)/$(basename "$BRAND_LOGO")"
  fi
fi

echo "🎯 Target Brand Configuration:"
echo "   - Title / Display Name:  $BRAND_NAME"
echo "   - Kebab Slug (Docker):   $BRAND_SLUG_KEBAB"
echo "   - Snake Slug (Database): $BRAND_SLUG_SNAKE"
echo "   - Flat Slug (Package):   $BRAND_SLUG_FLAT"
echo "   - Core Backend Name:     $CORE_APP_NAME"
echo "   - Web App Title:         $WEB_APP_NAME ($WEB_TITLE)"
echo "   - Mobile App Package:    $MOBILE_APP_NAME ($MOBILE_PACKAGE)"
if [ -n "$RESOLVED_LOGO_PATH" ]; then
  echo "   - Brand Logo:            $RESOLVED_LOGO_PATH"
elif [ -n "$BRAND_LOGO" ]; then
  echo "   - Brand Logo:            ⚠️ Not found at $BRAND_LOGO"
fi
echo "------------------------------------------------------------"

# Cross-platform sed -i helper (macOS BSD sed vs Linux GNU sed)
sedi() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Helper to update key=value in .env files safely
update_env_var() {
  local target_file="$1"
  local key="$2"
  local val="$3"

  if [ -f "$target_file" ]; then
    if grep -q "^#* *${key}=" "$target_file"; then
      sedi -E "s|^#* *${key}=.*|${key}=${val}|g" "$target_file"
    fi
  fi
}

# ------------------------------------------------------------
# 1. Rebrand Core Backend & Docker Infrastructure
# ------------------------------------------------------------
echo "⚙️  Rebranding Core Backend & Infrastructure..."

# Update Core .env and .env.example files
for env_file in "$CORE_DIR"/.env*; do
  if [ -f "$env_file" ]; then
    update_env_var "$env_file" "APP_NAME" "\"$CORE_APP_NAME\""
    update_env_var "$env_file" "RAILS_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-api"
    update_env_var "$env_file" "WAKA_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-waka"
    update_env_var "$env_file" "DB_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-db"
    update_env_var "$env_file" "MEDIA_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-media"
    update_env_var "$env_file" "GARAGE_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-garage"
    update_env_var "$env_file" "PG_DATABASE" "${BRAND_SLUG_SNAKE}_core"
    update_env_var "$env_file" "S3_BUCKET" "${BRAND_SLUG_KEBAB}"
    update_env_var "$env_file" "S3_ADMIN_TOKEN" "${BRAND_SLUG_SNAKE}_garage_admin_token_secret_key_12345"
    update_env_var "$env_file" "RAILS_JWT_SECRET_KEY" "${BRAND_SLUG_SNAKE}"
    update_env_var "$env_file" "FROM_EMAIL" "support@${BRAND_SLUG_FLAT}.me"
    update_env_var "$env_file" "SMTP_DOMAIN" "${BRAND_SLUG_FLAT}.me"
    echo "  ✅ Core: Updated env variables in $(basename "$env_file")"
  fi
done

# Update Core docker-compose.yaml (Production / Coolify)
if [ -f "$CORE_DIR/docker-compose.yaml" ]; then
  sedi -E "s|container_name: \\\$\{RAILS_CONTAINER_NAME:-[^}]*\}|container_name: \${RAILS_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-api}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|container_name: \\\$\{WAKA_CONTAINER_NAME:-[^}]*\}|container_name: \${WAKA_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-waka}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|container_name: \\\$\{MEDIA_CONTAINER_NAME:-[^}]*\}|container_name: \${MEDIA_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-media}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|container_name: \\\$\{DB_CONTAINER_NAME:-[^}]*\}|container_name: \${DB_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-db}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|container_name: \\\$\{GARAGE_CONTAINER_NAME:-[^}]*\}|container_name: \${GARAGE_CONTAINER_NAME:-${BRAND_SLUG_KEBAB}-garage}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|S3_BUCKET: \\\$\{S3_BUCKET:-[^}]*\}|S3_BUCKET: \${S3_BUCKET:-${BRAND_SLUG_KEBAB}}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|POSTGRES_DB: \\\$\{PG_DATABASE:-[^}]*\}|POSTGRES_DB: \${PG_DATABASE:-${BRAND_SLUG_SNAKE}_production}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|name: \\\$\{DOCKER_NETWORK:-[^}]*\}|name: \${DOCKER_NETWORK:-prod-${BRAND_SLUG_KEBAB}-net}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|name: \\\$\{POSTGRES_VOLUME:-[^}]*\}|name: \${POSTGRES_VOLUME:-prod-${BRAND_SLUG_KEBAB}-postgres-data}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|name: \\\$\{GARAGE_META_VOLUME:-[^}]*\}|name: \${GARAGE_META_VOLUME:-${BRAND_SLUG_KEBAB}-garage-meta}|g" "$CORE_DIR/docker-compose.yaml"
  sedi -E "s|name: \\\$\{GARAGE_DATA_VOLUME:-[^}]*\}|name: \${GARAGE_DATA_VOLUME:-${BRAND_SLUG_KEBAB}-garage-data}|g" "$CORE_DIR/docker-compose.yaml"
  echo "  ✅ Core: Synchronized docker-compose.yaml with prod-${BRAND_SLUG_KEBAB} containers"
fi

# Update Core docker-compose.dev.yaml (Development)
if [ -f "$CORE_DIR/docker-compose.dev.yaml" ]; then
  sedi -E "s|container_name: \\\$\{GARAGE_CONTAINER_NAME:-[^}]*\}|container_name: \${GARAGE_CONTAINER_NAME:-dev-${BRAND_SLUG_KEBAB}-core-garage}|g" "$CORE_DIR/docker-compose.dev.yaml"
  echo "  ✅ Core: Synchronized docker-compose.dev.yaml"
fi

# ------------------------------------------------------------
# 2. Rebrand Web Client & Docker Infrastructure
# ------------------------------------------------------------
WEB_DIR="$WORKSPACE_DIR/rexone-web"
if [ -d "$WEB_DIR" ]; then
  echo "🌐 Rebranding Web Client & Infrastructure ($WEB_DIR)..."

  # Update index.html (Title, Metadata, Canonical, OpenGraph, Twitter, Schema.org)
  if [ -f "$WEB_DIR/index.html" ]; then
    sedi -E "s|<title>.*</title>|<title>$WEB_TITLE</title>|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta name=\"title\" content=\"[^\"]*\"|<meta name=\"title\" content=\"$WEB_TITLE\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<link rel=\"canonical\" href=\"[^\"]*\"|<link rel=\"canonical\" href=\"https://${BRAND_SLUG_FLAT}.me/\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta property=\"og:site_name\" content=\"[^\"]*\"|<meta property=\"og:site_name\" content=\"${BRAND_NAME} Ecosystem\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta property=\"og:title\" content=\"[^\"]*\"|<meta property=\"og:title\" content=\"$WEB_TITLE\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta property=\"og:url\" content=\"[^\"]*\"|<meta property=\"og:url\" content=\"https://${BRAND_SLUG_FLAT}.me/\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta name=\"twitter:title\" content=\"[^\"]*\"|<meta name=\"twitter:title\" content=\"$WEB_TITLE\"|g" "$WEB_DIR/index.html"
    sedi -E "s|<meta name=\"twitter:url\" content=\"[^\"]*\"|<meta name=\"twitter:url\" content=\"https://${BRAND_SLUG_FLAT}.me/\"|g" "$WEB_DIR/index.html"
    if [ -n "$BRAND_DESC" ]; then
      sedi -E "s|<meta name=\"description\" content=\"[^\"]*\"|<meta name=\"description\" content=\"$BRAND_DESC\"|g" "$WEB_DIR/index.html"
      sedi -E "s|<meta property=\"og:description\" content=\"[^\"]*\"|<meta property=\"og:description\" content=\"$BRAND_DESC\"|g" "$WEB_DIR/index.html"
      sedi -E "s|<meta name=\"twitter:description\" content=\"[^\"]*\"|<meta name=\"twitter:description\" content=\"$BRAND_DESC\"|g" "$WEB_DIR/index.html"
    fi
    sedi -E "s|\"name\": \"[^\"]*\"|\"name\": \"$BRAND_NAME\"|g" "$WEB_DIR/index.html"
    sedi -E "s|\"url\": \"https://[^\"]*\"|\"url\": \"https://${BRAND_SLUG_FLAT}.me\"|g" "$WEB_DIR/index.html"
    echo "  ✅ Web: Updated index.html (Metadata, OpenGraph, Canonical & Schema.org)"
  fi

  # Update sitemap.xml and robots.txt
  if [ -f "$WEB_DIR/public/sitemap.xml" ]; then
    sedi -E "s|https://[^/]+/|https://${BRAND_SLUG_FLAT}.me/|g" "$WEB_DIR/public/sitemap.xml"
    echo "  ✅ Web: Updated public/sitemap.xml (https://${BRAND_SLUG_FLAT}.me)"
  fi
  if [ -f "$WEB_DIR/public/robots.txt" ]; then
    sedi -E "s|Sitemap: https://[^/]+/sitemap.xml|Sitemap: https://${BRAND_SLUG_FLAT}.me/sitemap.xml|g" "$WEB_DIR/public/robots.txt"
    echo "  ✅ Web: Updated public/robots.txt (Sitemap)"
  fi

  # Update package.json
  if [ -f "$WEB_DIR/package.json" ]; then
    sedi -E "s/\"name\": \"[^\"]*\"/\"name\": \"$BRAND_SLUG_KEBAB-web\"/g" "$WEB_DIR/package.json"
    echo "  ✅ Web: Updated package.json (\"name\": \"$BRAND_SLUG_KEBAB-web\")"
  fi

  # Update queryClient cache key
  if [ -f "$WEB_DIR/src/services/queryClient.ts" ]; then
    sedi -E "s/\"[a-z0-9_-]+_react_query_cache\"/\"${BRAND_SLUG_SNAKE}_react_query_cache\"/g" "$WEB_DIR/src/services/queryClient.ts"
    echo "  ✅ Web: Updated React Query cache key to \"${BRAND_SLUG_SNAKE}_react_query_cache\""
  fi

  # Update locales/en.json if brand name mentioned
  if [ -f "$WEB_DIR/src/locales/en.json" ]; then
    sedi -E "s/\"title\": \"Welcome to [^\"]*\"/\"title\": \"Welcome to $BRAND_NAME\"/g" "$WEB_DIR/src/locales/en.json"
    echo "  ✅ Web: Updated brand references in src/locales/en.json"
  fi

  # Update Web .env files and .env.example
  for env_file in "$WEB_DIR"/.env*; do
    if [ -f "$env_file" ]; then
      update_env_var "$env_file" "VITE_APP_NAME" "\"$WEB_APP_NAME\""
      update_env_var "$env_file" "VITE_REACT_APP_NAME" "$BRAND_NAME"
      echo "  ✅ Web: Updated $(basename "$env_file")"
    fi
  done

  # Update Web docker-compose.yaml
  if [ -f "$WEB_DIR/docker-compose.yaml" ]; then
    sedi -E "s|container_name: \\\$\{WEB_CONTAINER_NAME:-[^}]*\}|container_name: \${WEB_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-web}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|name: \\\$\{DOCKER_NETWORK:-[^}]*\}|name: \${DOCKER_NETWORK:-prod-${BRAND_SLUG_KEBAB}-net}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_NAME: \\\$\{VITE_REACT_APP_NAME:-[^}]*\}|VITE_REACT_APP_NAME: \${VITE_REACT_APP_NAME:-${BRAND_SLUG_FLAT}.me}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_SERVER_BASE_URL: \\\$\{VITE_REACT_APP_SERVER_BASE_URL:-[^}]*\}|VITE_REACT_APP_SERVER_BASE_URL: \${VITE_REACT_APP_SERVER_BASE_URL:-https://api.${BRAND_SLUG_FLAT}.me}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_CLIENT_BASE_URL: \\\$\{VITE_REACT_APP_CLIENT_BASE_URL:-[^}]*\}|VITE_REACT_APP_CLIENT_BASE_URL: \${VITE_REACT_APP_CLIENT_BASE_URL:-https://${BRAND_SLUG_FLAT}.me}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_SERVER_WS_BASE_URL: \\\$\{VITE_REACT_APP_SERVER_WS_BASE_URL:-[^}]*\}|VITE_REACT_APP_SERVER_WS_BASE_URL: \${VITE_REACT_APP_SERVER_WS_BASE_URL:-wss://api.${BRAND_SLUG_FLAT}.me}|g" "$WEB_DIR/docker-compose.yaml"
    echo "  ✅ Web: Synchronized docker-compose.yaml with prod-${BRAND_SLUG_KEBAB}-web"
  fi

  # Update Web docker-compose.dev.yaml
  if [ -f "$WEB_DIR/docker-compose.dev.yaml" ]; then
    sedi -E "s|container_name: dev-[^ ]*|container_name: dev-${BRAND_SLUG_KEBAB}-web|g" "$WEB_DIR/docker-compose.dev.yaml"
    echo "  ✅ Web: Synchronized docker-compose.dev.yaml (dev-${BRAND_SLUG_KEBAB}-web)"
  fi

  # Copy logo if provided
  if [ -n "$RESOLVED_LOGO_PATH" ]; then
    mkdir -p "$WEB_DIR/public/brand"
    cp "$RESOLVED_LOGO_PATH" "$WEB_DIR/public/brand/logo.png"
    cp "$RESOLVED_LOGO_PATH" "$WEB_DIR/public/favicon.png"
    echo "  ✅ Web: Updated public/brand/logo.png and favicon from $(basename "$RESOLVED_LOGO_PATH")"
  fi
else
  echo "ℹ️  Web repository not found at $WEB_DIR (skipping)"
fi

# ------------------------------------------------------------
# 3. Rebrand Mobile Client
# ------------------------------------------------------------
MOBILE_DIR="$WORKSPACE_DIR/rexone_mobile"
if [ -d "$MOBILE_DIR" ]; then
  echo "📱 Rebranding Mobile Client ($MOBILE_DIR)..."

  if [ -f "$MOBILE_DIR/scripts/rebrand.sh" ]; then
    bash "$MOBILE_DIR/scripts/rebrand.sh" "$MOBILE_APP_NAME" "$MOBILE_PACKAGE" "$RESOLVED_LOGO_PATH" "$BRAND_NAME"
  fi
else
  echo "ℹ️  Mobile repository not found at $MOBILE_DIR (skipping)"
fi

echo "============================================================"
echo "🎉 REBRANDING COMPLETED SUCCESSFULLY FOR: $BRAND_NAME"
echo "   Docker Kebab Slug:    $BRAND_SLUG_KEBAB"
echo "   Database Snake Slug:  $BRAND_SLUG_SNAKE"
echo "   Foundation: Built on top of the RexOne Ecosystem (rex-9)"
echo "============================================================"
