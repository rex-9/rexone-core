#!/bin/bash
# scripts/rebrand.sh
# Master Rebranding Script for Rexone Ecosystem (Core, Web, Mobile)
# Run from rexone-core: ./scripts/rebrand.sh [path/to/brand.config.json]

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

# Helper to read JSON values via node, python3, or ruby
read_json() {
  ruby -rjson -e "c = JSON.parse(File.read('$CONFIG_FILE')); val = $1; puts val unless val.nil?" 2>/dev/null || \
  node -e "const c = require('$CONFIG_FILE'); const val = $1; if (val !== undefined) console.log(val);" 2>/dev/null || \
  python3 -c "import json; c = json.load(open('$CONFIG_FILE')); val = $1; print(val if val is not None else '')" 2>/dev/null || true
}

BRAND_NAME=$(read_json "c.dig('brand', 'name')")
BRAND_SLUG=$(read_json "c.dig('brand', 'slug')")
BRAND_SHORT_NAME=$(read_json "c.dig('brand', 'shortName') || c.dig('brand', 'name')")
BRAND_DESC=$(read_json "c.dig('brand', 'description')")
BRAND_LOGO=$(read_json "c.dig('brand', 'logoPath')")

MOBILE_APP_NAME=$(read_json "c.dig('mobile', 'appName') || c.dig('brand', 'name')")
MOBILE_PACKAGE=$(read_json "c.dig('mobile', 'packageName')")

WEB_APP_NAME=$(read_json "c.dig('web', 'appName') || c.dig('brand', 'name')")
WEB_TITLE=$(read_json "c.dig('web', 'title') || c.dig('brand', 'name')")

CORE_APP_NAME=$(read_json "c.dig('core', 'appName') || c.dig('brand', 'name')")

RESOLVED_LOGO_PATH=""
if [ -n "$BRAND_LOGO" ]; then
  if [ -f "$CORE_DIR/$BRAND_LOGO" ]; then
    RESOLVED_LOGO_PATH="$CORE_DIR/$BRAND_LOGO"
  elif [ -f "$BRAND_LOGO" ]; then
    RESOLVED_LOGO_PATH="$(cd "$(dirname "$BRAND_LOGO")" && pwd)/$(basename "$BRAND_LOGO")"
  fi
fi

echo "🎯 Target Brand Configuration:"
echo "   - Brand Name:    $BRAND_NAME"
echo "   - Brand Slug:    $BRAND_SLUG"
echo "   - Core Backend:  $CORE_APP_NAME"
echo "   - Web App:       $WEB_APP_NAME ($WEB_TITLE)"
echo "   - Mobile App:    $MOBILE_APP_NAME ($MOBILE_PACKAGE)"
if [ -n "$RESOLVED_LOGO_PATH" ]; then
  echo "   - Brand Logo:    $RESOLVED_LOGO_PATH"
elif [ -n "$BRAND_LOGO" ]; then
  echo "   - Brand Logo:    ⚠️ Not found at $BRAND_LOGO"
fi
echo "------------------------------------------------------------"


# ------------------------------------------------------------
# 1. Rebrand Rexone Core
# ------------------------------------------------------------
echo "⚙️  Rebranding Rexone Core..."
for env_file in "$CORE_DIR"/.env*; do
  if [ -f "$env_file" ]; then
    if grep -q "APP_NAME=" "$env_file"; then
      sed -i '' -E "s/^APP_NAME=.*/APP_NAME=\"$CORE_APP_NAME\"/g" "$env_file"
    fi
    echo "  ✅ Core: Updated $(basename "$env_file")"
  fi
done

# ------------------------------------------------------------
# 2. Rebrand Rexone Web (if present)
# ------------------------------------------------------------
WEB_DIR="$WORKSPACE_DIR/rexone-web"
if [ -d "$WEB_DIR" ]; then
  echo "🌐 Rebranding Rexone Web ($WEB_DIR)..."

  # Update index.html
  if [ -f "$WEB_DIR/index.html" ]; then
    sed -i '' -E "s/<title>.*<\/title>/<title>$WEB_TITLE<\/title>/g" "$WEB_DIR/index.html"
    if [ -n "$BRAND_DESC" ]; then
      sed -i '' -E "s/<meta name=\"description\" content=\"[^\"]*\"/<meta name=\"description\" content=\"$BRAND_DESC\"/g" "$WEB_DIR/index.html"
    fi
    echo "  ✅ Web: Updated index.html"
  fi

  # Update package.json
  if [ -f "$WEB_DIR/package.json" ]; then
    sed -i '' -E "s/\"name\": \"[^\"]*\"/\"name\": \"$BRAND_SLUG-web\"/g" "$WEB_DIR/package.json"
    echo "  ✅ Web: Updated package.json"
  fi

  # Update .env files
  for env_file in "$WEB_DIR"/.env*; do
    if [ -f "$env_file" ]; then
      if grep -q "VITE_APP_NAME=" "$env_file"; then
        sed -i '' -E "s/^VITE_APP_NAME=.*/VITE_APP_NAME=\"$WEB_APP_NAME\"/g" "$env_file"
      fi
      echo "  ✅ Web: Updated $(basename "$env_file")"
    fi
  done

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
# 3. Rebrand Rexone Mobile (if present)
# ------------------------------------------------------------
MOBILE_DIR="$WORKSPACE_DIR/rexone_mobile"
if [ -d "$MOBILE_DIR" ]; then
  echo "📱 Rebranding Rexone Mobile ($MOBILE_DIR)..."
  
  if [ -f "$MOBILE_DIR/scripts/rebrand.sh" ]; then
    bash "$MOBILE_DIR/scripts/rebrand.sh" "$MOBILE_APP_NAME" "$MOBILE_PACKAGE" "$RESOLVED_LOGO_PATH"
  fi

else
  echo "ℹ️  Mobile repository not found at $MOBILE_DIR (skipping)"
fi

echo "============================================================"
echo "🎉 REBRANDING COMPLETED SUCCESSFULLY FOR: $BRAND_NAME"
echo "   Foundation: Built on top of the Rexone Ecosystem (rex-9)"
echo "============================================================"
