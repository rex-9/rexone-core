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
if [[ "$CONFIG_FILE" != /* ]]; then
  if [ -f "$PWD/$CONFIG_FILE" ]; then
    CONFIG_FILE="$PWD/$CONFIG_FILE"
  elif [ -f "$CORE_DIR/$CONFIG_FILE" ]; then
    CONFIG_FILE="$CORE_DIR/$CONFIG_FILE"
  fi
fi

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
  local key_path="$1"
  if command -v node >/dev/null 2>&1 && node -e "process.exit(0)" 2>/dev/null; then
    node -e "
      const fs = require('fs');
      try {
        const c = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
        const parts = '$key_path'.split('.');
        let val = c;
        for (const p of parts) {
          val = (val && typeof val === 'object') ? val[p] : undefined;
        }
        if (val !== undefined && val !== null) console.log(val);
      } catch (_) {}
    " 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        c = json.load(f)
    parts = '$key_path'.split('.')
    val = c
    for p in parts:
        val = val[p] if isinstance(val, dict) else None
    if val is not None:
        print(val)
except Exception:
    pass
" 2>/dev/null
  elif command -v ruby >/dev/null 2>&1; then
    ruby -rjson -e "
      begin
        c = JSON.parse(File.read('$CONFIG_FILE'))
        parts = '$key_path'.split('.')
        val = parts.inject(c) { |acc, k| acc.is_a?(Hash) ? acc[k] : nil }
        puts val unless val.nil?
      rescue
      end
    " 2>/dev/null
  fi
}

BRAND_NAME=$(read_json "brand.name")
BRAND_SLUG_RAW=$(read_json "brand.slug")
BRAND_SHORT_NAME=$(read_json "brand.shortName")
[ -z "$BRAND_SHORT_NAME" ] && BRAND_SHORT_NAME="$BRAND_NAME"
BRAND_DESC=$(read_json "brand.description")
BRAND_LOGO=$(read_json "brand.logoPath")
BRAND_DOMAIN=$(read_json "brand.domain")
BRAND_SUPPORT_EMAIL=$(read_json "brand.supportEmail")
[ -z "$BRAND_SUPPORT_EMAIL" ] && BRAND_SUPPORT_EMAIL=$(read_json "brand.support_email")
[ -z "$BRAND_SUPPORT_EMAIL" ] && BRAND_SUPPORT_EMAIL=$(read_json "core.mailerSender")

MOBILE_APP_NAME=$(read_json "mobile.appName")
[ -z "$MOBILE_APP_NAME" ] && MOBILE_APP_NAME="$BRAND_NAME"
MOBILE_PACKAGE=$(read_json "mobile.packageName")

WEB_APP_NAME=$(read_json "web.appName")
[ -z "$WEB_APP_NAME" ] && WEB_APP_NAME="$BRAND_NAME"
WEB_TITLE=$(read_json "web.title")
[ -z "$WEB_TITLE" ] && WEB_TITLE="$BRAND_NAME"

CORE_APP_NAME=$(read_json "core.appName")
[ -z "$CORE_APP_NAME" ] && CORE_APP_NAME="$BRAND_NAME"

SLUG_SOURCE="${BRAND_SLUG_RAW:-$BRAND_NAME}"

# Derive standardized naming forms per docs/NAMING_CONVENTIONS.md
BRAND_SLUG_KEBAB=$(node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''))" 2>/dev/null || echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//')
BRAND_SLUG_SNAKE=$(node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, ''))" 2>/dev/null || echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '_' | sed 's/^_//;s/_$//')
BRAND_SLUG_FLAT=$(node -e "console.log('$SLUG_SOURCE'.toLowerCase().replace(/[^a-z0-9]/g, ''))" 2>/dev/null || echo "$SLUG_SOURCE" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')

if [ -z "$BRAND_DOMAIN" ]; then
  BRAND_DOMAIN="${BRAND_SLUG_FLAT}.com"
fi
if [ -z "$MOBILE_PACKAGE" ]; then
  MOBILE_PACKAGE="com.rex9.${BRAND_SLUG_FLAT}"
fi

RESOLVED_FROM_EMAIL="${BRAND_SUPPORT_EMAIL:-support@${BRAND_DOMAIN}}"
RESOLVED_SMTP_DOMAIN="${BRAND_DOMAIN}"
if [ "$BRAND_NAME" = "RexOne" ]; then
  RESOLVED_FROM_EMAIL="support@rexone.com"
  RESOLVED_SMTP_DOMAIN="rexone.com"
fi

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
echo "   - Canonical Domain:      $BRAND_DOMAIN"
echo "   - Support Email:         $RESOLVED_FROM_EMAIL"
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
    if grep -q "^${key}=" "$target_file"; then
      sedi -E "s|^${key}=.*|${key}=${val}|g" "$target_file"
    fi
  fi
}

# ------------------------------------------------------------
# 1. Rebrand Core Backend & Docker Infrastructure
# ------------------------------------------------------------
echo "⚙️  Rebranding Core Backend & Infrastructure..."

# Update Core .env.example file (Law U16 & Secret Isolation: never touch local gitignored .env files)
if [ -f "$CORE_DIR/.env.example" ]; then
  update_env_var "$CORE_DIR/.env.example" "PG_DATABASE" "${BRAND_SLUG_SNAKE}_core"
  update_env_var "$CORE_DIR/.env.example" "S3_BUCKET" "${BRAND_SLUG_KEBAB}"
  update_env_var "$CORE_DIR/.env.example" "FROM_EMAIL" "${RESOLVED_FROM_EMAIL}"
  update_env_var "$CORE_DIR/.env.example" "SMTP_DOMAIN" "${RESOLVED_SMTP_DOMAIN}"
  update_env_var "$CORE_DIR/.env.example" "RAILS_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-api"
  update_env_var "$CORE_DIR/.env.example" "WAKA_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-waka"
  update_env_var "$CORE_DIR/.env.example" "DB_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-db"
  update_env_var "$CORE_DIR/.env.example" "MEDIA_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-media"
  update_env_var "$CORE_DIR/.env.example" "GARAGE_CONTAINER_NAME" "dev-${BRAND_SLUG_KEBAB}-core-garage"
  # Commented example lines in .env.example
  sedi -E "s|^# PRODUCT_DOMAIN=.*|# PRODUCT_DOMAIN=${RESOLVED_SMTP_DOMAIN}|g" "$CORE_DIR/.env.example"
  sedi -E "s|^# CORS_ORIGINS=.*|# CORS_ORIGINS=https://${RESOLVED_SMTP_DOMAIN},https://uat.${RESOLVED_SMTP_DOMAIN}|g" "$CORE_DIR/.env.example"
  sedi -E "s|^# GOOGLE_PLAY_PACKAGE_NAME=.*|# GOOGLE_PLAY_PACKAGE_NAME=${MOBILE_PACKAGE}|g" "$CORE_DIR/.env.example"
  sedi -E "s|^# APPLE_APP_STORE_BUNDLE_ID=.*|# APPLE_APP_STORE_BUNDLE_ID=${MOBILE_PACKAGE}|g" "$CORE_DIR/.env.example"
  echo "  ✅ Core: Updated .env.example"
fi

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
  sedi -E "s|container_name: \\\$\{DB_CONTAINER_NAME:-[^}]*\}|container_name: \${DB_CONTAINER_NAME:-dev-${BRAND_SLUG_KEBAB}-core-db}|g" "$CORE_DIR/docker-compose.dev.yaml"
  sedi -E "s|container_name: \\\$\{RAILS_CONTAINER_NAME:-[^}]*\}|container_name: \${RAILS_CONTAINER_NAME:-dev-${BRAND_SLUG_KEBAB}-core-api}|g" "$CORE_DIR/docker-compose.dev.yaml"
  sedi -E "s|container_name: \\\$\{WAKA_CONTAINER_NAME:-[^}]*\}|container_name: \${WAKA_CONTAINER_NAME:-dev-${BRAND_SLUG_KEBAB}-core-waka}|g" "$CORE_DIR/docker-compose.dev.yaml"
  sedi -E "s|container_name: \\\$\{MEDIA_CONTAINER_NAME:-[^}]*\}|container_name: \${MEDIA_CONTAINER_NAME:-dev-${BRAND_SLUG_KEBAB}-core-media}|g" "$CORE_DIR/docker-compose.dev.yaml"
  echo "  ✅ Core: Synchronized docker-compose.dev.yaml"
fi

# Update Core maintenance scripts with new container/DB fallbacks
if [ -f "$CORE_DIR/scripts/backup_db.sh" ]; then
  sedi -E "s/dev-[a-z0-9_-]+-core-db/dev-${BRAND_SLUG_KEBAB}-core-db/g" "$CORE_DIR/scripts/backup_db.sh"
  sedi -E "s/[a-z0-9_-]+_core_production/${BRAND_SLUG_SNAKE}_core_production/g" "$CORE_DIR/scripts/backup_db.sh"
  sedi -E "s/[a-z0-9_-]+_core_development/${BRAND_SLUG_SNAKE}_core_development/g" "$CORE_DIR/scripts/backup_db.sh"
  echo "  ✅ Core: Synchronized scripts/backup_db.sh"
fi
if [ -f "$CORE_DIR/scripts/backup_garage.sh" ]; then
  sedi -E "s/dev-[a-z0-9_-]+-core-garage/dev-${BRAND_SLUG_KEBAB}-core-garage/g" "$CORE_DIR/scripts/backup_garage.sh"
  echo "  ✅ Core: Synchronized scripts/backup_garage.sh"
fi
if [ -f "$CORE_DIR/scripts/dev_garage.sh" ]; then
  sedi -E "s/dev-[a-z0-9_-]+-core-garage/dev-${BRAND_SLUG_KEBAB}-core-garage/g" "$CORE_DIR/scripts/dev_garage.sh"
  sedi -E "s/KEY_NAME=\"[^\"]*\"/KEY_NAME=\"${BRAND_SLUG_KEBAB}-key\"/g" "$CORE_DIR/scripts/dev_garage.sh"
  sedi -E "s/BUCKET_NAME=\"\\\$\{S3_BUCKET:-[^}]*\}\"/BUCKET_NAME=\"\${S3_BUCKET:-${BRAND_SLUG_KEBAB}}\"/g" "$CORE_DIR/scripts/dev_garage.sh"
  echo "  ✅ Core: Synchronized scripts/dev_garage.sh"
fi
if [ -f "$CORE_DIR/scripts/prod_garage_init.sh" ]; then
  sedi -E "s/GARAGE_KEY_NAME:-[a-z0-9_-]*-key/GARAGE_KEY_NAME:-${BRAND_SLUG_KEBAB}-key/g" "$CORE_DIR/scripts/prod_garage_init.sh"
  echo "  ✅ Core: Synchronized scripts/prod_garage_init.sh"
fi

# Update Core application config fallbacks
if [ -f "$CORE_DIR/config/app_config.rb" ]; then
  sedi -E "s/env_or\.call\(\"RAILS_JWT_SECRET_KEY\", \"[^\"]*\"\)/env_or.call(\"RAILS_JWT_SECRET_KEY\", \"${BRAND_SLUG_SNAKE}\")/g" "$CORE_DIR/config/app_config.rb"
  sedi -E "s/env_or\.call\(\"SMTP_DOMAIN\", \"[^\"]*\"\)/env_or.call(\"SMTP_DOMAIN\", \"${RESOLVED_SMTP_DOMAIN}\")/g" "$CORE_DIR/config/app_config.rb"
  sedi -E "s/env_or\.call\(\"FROM_EMAIL\", \"[^\"]*\"\)/env_or.call(\"FROM_EMAIL\", \"${RESOLVED_FROM_EMAIL}\")/g" "$CORE_DIR/config/app_config.rb"
  sedi -E "s/env_or\.call\(\"S3_BUCKET\", \"[^\"]*\"\)/env_or.call(\"S3_BUCKET\", \"${BRAND_SLUG_KEBAB}\")/g" "$CORE_DIR/config/app_config.rb"
  core_url_scheme="${BRAND_SLUG_FLAT}"
  if [ "$BRAND_NAME" = "RexOne" ]; then
    core_url_scheme="rexone"
  fi
  sedi -E "s/\"[a-z0-9_-]+:\/\/\"\)/\"${core_url_scheme}:\/\/\")/g" "$CORE_DIR/config/app_config.rb"
  echo "  ✅ Core: Synchronized config/app_config.rb fallbacks"
fi

# Update Core database configuration templates
for db_file in "$CORE_DIR/config/database.yml" "$CORE_DIR/config/database.example.yml"; do
  if [ -f "$db_file" ]; then
    sedi -E "s/[a-z0-9_]+_core_development/${BRAND_SLUG_SNAKE}_core_development/g" "$db_file"
    sedi -E "s/[a-z0-9_]+_core_test/${BRAND_SLUG_SNAKE}_core_test/g" "$db_file"
    sedi -E "s/[a-z0-9_]+_core_production/${BRAND_SLUG_SNAKE}_core_production/g" "$db_file"
    sedi -E "s/username: [a-z0-9_]+_core/username: ${BRAND_SLUG_SNAKE}_core/g" "$db_file"
    echo "  ✅ Core: Synchronized $(basename "$db_file")"
  fi
done

# Update Core garage.toml tokens
if [ -f "$CORE_DIR/config/garage.toml" ]; then
  sedi -E "s/admin_token = \"[^\"]*\"/admin_token = \"${BRAND_SLUG_SNAKE}_garage_admin_token_secret_key_12345\"/g" "$CORE_DIR/config/garage.toml"
  sedi -E "s/metrics_token = \"[^\"]*\"/metrics_token = \"${BRAND_SLUG_SNAKE}_garage_metrics_token_secret_key_12345\"/g" "$CORE_DIR/config/garage.toml"
  echo "  ✅ Core: Synchronized config/garage.toml"
fi

# Update Core security boot guard
if [ -f "$CORE_DIR/config/initializers/security_boot_guard.rb" ]; then
  sedi -E "s/\"[a-z0-9_]+_garage_admin_token_secret_key_12345\"/\"${BRAND_SLUG_SNAKE}_garage_admin_token_secret_key_12345\"/g" "$CORE_DIR/config/initializers/security_boot_guard.rb"
  echo "  ✅ Core: Synchronized config/initializers/security_boot_guard.rb"
fi

# Update Core Devise mailer sender
if [ -f "$CORE_DIR/config/initializers/devise.rb" ]; then
  sedi -E "s/config\.mailer_sender = .*/config.mailer_sender = AppConfig::FROM_EMAIL/g" "$CORE_DIR/config/initializers/devise.rb"
  echo "  ✅ Core: Synchronized config/initializers/devise.rb (AppConfig::FROM_EMAIL)"
fi

# Update Core speech user agent & session system
if [ -f "$CORE_DIR/app/constants/speech_constants.rb" ]; then
  sedi -E "s/AZURE_USER_AGENT = \"[^\"]*\"/AZURE_USER_AGENT = \"${BRAND_SLUG_KEBAB}-core\"/g" "$CORE_DIR/app/constants/speech_constants.rb"
  echo "  ✅ Core: Synchronized speech_constants.rb"
fi
if [ -f "$CORE_DIR/app/services/speech_service/session.rb" ]; then
  sedi -E "s/name: \"[a-z0-9_-]+-core\"/name: \"${BRAND_SLUG_KEBAB}-core\"/g" "$CORE_DIR/app/services/speech_service/session.rb"
  echo "  ✅ Core: Synchronized speech_service/session.rb"
fi

# Update Core notification defaults and locales
if [ -f "$CORE_DIR/app/constants/notification_constants.rb" ]; then
  sedi -E "s/Welcome to [^\"',!]+/Welcome to ${BRAND_NAME}/g" "$CORE_DIR/app/constants/notification_constants.rb"
  sedi -E "s/joining [^\"'!]+!/joining ${BRAND_NAME}!/g" "$CORE_DIR/app/constants/notification_constants.rb"
  echo "  ✅ Core: Synchronized notification_constants.rb"
fi
if [ -f "$CORE_DIR/config/locales/notification.en.yml" ]; then
  sedi -E "s/[^\"']+ will be temporarily unavailable/${BRAND_NAME} will be temporarily unavailable/g" "$CORE_DIR/config/locales/notification.en.yml"
  sedi -E "s/A new [^\"']+ feature/A new ${BRAND_NAME} feature/g" "$CORE_DIR/config/locales/notification.en.yml"
  echo "  ✅ Core: Synchronized notification.en.yml"
fi
if [ -f "$CORE_DIR/config/locales/notification.my.yml" ]; then
  sedi -E "s/စနစ် ပြင်ဆင်နေစဉ် [^\"]+ ကို/စနစ် ပြင်ဆင်နေစဉ် ${BRAND_NAME} ကို/g" "$CORE_DIR/config/locales/notification.my.yml"
  sedi -E "s/\"[^\"]+ လုပ်ဆောင်ချက်အသစ်/\"${BRAND_NAME} လုပ်ဆောင်ချက်အသစ်/g" "$CORE_DIR/config/locales/notification.my.yml"
  echo "  ✅ Core: Synchronized notification.my.yml"
fi

# Update Core email template renderer
if [ -f "$CORE_DIR/app/services/email_service/template_renderer.rb" ]; then
  sedi -E "s/registered user of [^.]+\./registered user of ${BRAND_NAME}./g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  sedi -E "s/Confirm your [^\"']+ email/Confirm your ${BRAND_NAME} email/g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  sedi -E "s/Reset your [^\"']+ passcode/Reset your ${BRAND_NAME} passcode/g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  sedi -E "s/Welcome to [^\"'!]+/Welcome to ${BRAND_NAME}/g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  sedi -E "s/joining [^\"'!\.]+(\.|\!)/joining ${BRAND_NAME}\1/g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  sedi -E "s/Open [^\"'\/\\<]+(\"|;|\$)/Open ${BRAND_NAME}\1/g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  copyright_name="${BRAND_NAME}"
  if [ "$BRAND_NAME" = "RexOne" ]; then
    copyright_name="RexOne Ecosystem"
  fi
  sedi -E "s/(&copy;|\\&copy;)[^<]+/\\&copy; 2026 ${copyright_name}. All rights reserved./g" "$CORE_DIR/app/services/email_service/template_renderer.rb"
  echo "  ✅ Core: Synchronized template_renderer.rb"
fi

# Update Core Swagger title
if [ -f "$CORE_DIR/spec/swagger_helper.rb" ]; then
  sedi -E "s/title: '[^']* Core API'/title: '${BRAND_NAME} Core API'/g" "$CORE_DIR/spec/swagger_helper.rb"
  echo "  ✅ Core: Synchronized spec/swagger_helper.rb"
fi

# Update Core admin stylesheet comment
if [ -f "$CORE_DIR/app/assets/stylesheets/admin.css" ]; then
  sedi -E "s/[^ \t\r\n].* Design Tokens/${BRAND_NAME} Design Tokens/g" "$CORE_DIR/app/assets/stylesheets/admin.css"
  echo "  ✅ Core: Synchronized admin.css"
fi

# ------------------------------------------------------------
# 2. Rebrand Web Client & Docker Infrastructure
# ------------------------------------------------------------
WEB_DIR="$WORKSPACE_DIR/rexone-web"
if [ -d "$WEB_DIR" ]; then
  echo "🌐 Rebranding Web Client & Infrastructure ($WEB_DIR)..."

  # SEO & AI Discovery Isolation:
  # RexOne SEO (index.html metadata/Schema.org, robots.txt, sitemap.xml, llms.txt, llms-full.txt)
  # is intentionally excluded from rebrand automation to keep RexOne as the sovereign foundation
  # architecture product. Downstream derivative products (e.g. MeritMoon) must define their own
  # product-specific SEO, metadata, and landing architecture — it is 100% developer responsibility.
  echo "  ℹ️  Web Note: SEO & AI Discovery assets (index.html, robots.txt, sitemap.xml, llms.txt, llms-full.txt) are intentionally left untouched. RexOne is the foundation architecture product; product SEO is developer responsibility."

  # Update package.json
  if [ -f "$WEB_DIR/package.json" ]; then
    sedi -E "s/\"name\": \"[^\"]*\"/\"name\": \"$BRAND_SLUG_KEBAB-web\"/g" "$WEB_DIR/package.json"
    echo "  ✅ Web: Updated package.json (\"name\": \"$BRAND_SLUG_KEBAB-web\")"
  fi

  # Update AppConfig.tsx default APP_NAME fallback
  if [ -f "$WEB_DIR/src/AppConfig.tsx" ]; then
    app_name_fallback="$BRAND_NAME"
    if [ "$BRAND_NAME" = "RexOne" ]; then
      app_name_fallback="rexone.com"
    fi
    sedi -E "s/APP_NAME = import\.meta\.env\.VITE_REACT_APP_NAME \|\| \"[^\"]*\"/APP_NAME = import.meta.env.VITE_REACT_APP_NAME || \"$app_name_fallback\"/g" "$WEB_DIR/src/AppConfig.tsx"
    sedi -E "s/FROM_EMAIL = import\.meta\.env\.VITE_REACT_APP_FROM_EMAIL \|\| \"[^\"]*\"/FROM_EMAIL = import.meta.env.VITE_REACT_APP_FROM_EMAIL || \"${RESOLVED_FROM_EMAIL}\"/g" "$WEB_DIR/src/AppConfig.tsx"
    echo "  ✅ Web: Updated AppConfig.tsx default APP_NAME to \"$app_name_fallback\""
  fi


  # Update queryClient cache key
  if [ -f "$WEB_DIR/src/services/queryClient.ts" ]; then
    sedi -E "s/\"[a-z0-9_-]*_react_query_cache\"/\"${BRAND_SLUG_SNAKE}_react_query_cache\"/g" "$WEB_DIR/src/services/queryClient.ts"
    echo "  ✅ Web: Updated React Query cache key to \"${BRAND_SLUG_SNAKE}_react_query_cache\""
  fi

  # Update locales/en.json and my.json
  if [ -f "$WEB_DIR/src/locales/en.json" ]; then
    sedi -E "s/\"Welcome to [^\"]*\"/\"Welcome to $BRAND_NAME\"/g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/to help improve [^.]+\./to help improve ${BRAND_NAME}./g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/e\.g\. Open [^,]+,/e.g. Open ${BRAND_NAME},/g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/Defaults to 'Open [^']+'/Defaults to 'Open ${BRAND_NAME}'/g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/Tap to open in [^\"]+\"/Tap to open in ${BRAND_NAME}\"/g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/[^\"•]+ Ecosystem •/${BRAND_NAME} Ecosystem •/g" "$WEB_DIR/src/locales/en.json"
    sedi -E "s/joining [^!]+!/joining ${BRAND_NAME}!/g" "$WEB_DIR/src/locales/en.json"
    echo "  ✅ Web: Updated brand references in src/locales/en.json"
  fi
  if [ -f "$WEB_DIR/src/locales/my.json" ]; then
    sedi -E "s/\"[^\"]+ ပိုမိုကောင်းမွန်စေရန်/\"${BRAND_NAME} ပိုမိုကောင်းမွန်စေရန်/g" "$WEB_DIR/src/locales/my.json"
    sedi -E "s/\"[^\"]+ မှ ကြိုဆိုပါသည်\"/\"${BRAND_NAME} မှ ကြိုဆိုပါသည်\"/g" "$WEB_DIR/src/locales/my.json"
    sedi -E "s/Open [^၊]+၊/Open ${BRAND_NAME}၊/g" "$WEB_DIR/src/locales/my.json"
    sedi -E "s/'Open [^']+' ဖြစ်မည်/'Open ${BRAND_NAME}' ဖြစ်မည်/g" "$WEB_DIR/src/locales/my.json"
    sedi -E "s/\"[^\"]+ တွင် ဖွင့်ကြည့်ရန်/\"${BRAND_NAME} တွင် ဖွင့်ကြည့်ရန်/g" "$WEB_DIR/src/locales/my.json"
    sedi -E "s/\"[^\"]+ ဂေဟစနစ် •/\"${BRAND_NAME} ဂေဟစနစ် •/g" "$WEB_DIR/src/locales/my.json"
    echo "  ✅ Web: Updated brand references in src/locales/my.json"
  fi

  # Update Web .env.example (Law U16 & Secret Isolation)
  if [ -f "$WEB_DIR/.env.example" ]; then
    web_env_name="$BRAND_NAME"
    web_domain="${RESOLVED_SMTP_DOMAIN}"
    if [ "$BRAND_NAME" = "RexOne" ]; then
      web_env_name="rexone.com"
      web_domain="rexone.com"
    fi
    update_env_var "$WEB_DIR/.env.example" "VITE_REACT_APP_NAME" "$web_env_name"
    update_env_var "$WEB_DIR/.env.example" "VITE_REACT_APP_FROM_EMAIL" "${RESOLVED_FROM_EMAIL}"
    node -e "
      const fs = require('fs');
      const f = '$WEB_DIR/.env.example';
      let c = fs.readFileSync(f, 'utf8');
      c = c.replace(/# Production Tier \(e\.g\. [^)]*\):\n#\s+VITE_REACT_APP_CLIENT_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_WS_BASE_URL=[^\n]*/,
        '# Production Tier (e.g. $BRAND_NAME):\n#   VITE_REACT_APP_CLIENT_BASE_URL=https://$web_domain\n#   VITE_REACT_APP_SERVER_BASE_URL=https://api.$web_domain\n#   VITE_REACT_APP_SERVER_WS_BASE_URL=wss://api.$web_domain');
      c = c.replace(/# UAT Tier:\n#\s+VITE_REACT_APP_CLIENT_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_WS_BASE_URL=[^\n]*/,
        '# UAT Tier:\n#   VITE_REACT_APP_CLIENT_BASE_URL=https://uat.$web_domain\n#   VITE_REACT_APP_SERVER_BASE_URL=https://uat.api.$web_domain\n#   VITE_REACT_APP_SERVER_WS_BASE_URL=wss://uat.api.$web_domain');
      c = c.replace(/# Dev Tier:\n#\s+VITE_REACT_APP_CLIENT_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_BASE_URL=[^\n]*\n#\s+VITE_REACT_APP_SERVER_WS_BASE_URL=[^\n]*/,
        '# Dev Tier:\n#   VITE_REACT_APP_CLIENT_BASE_URL=https://dev.$web_domain\n#   VITE_REACT_APP_SERVER_BASE_URL=https://dev.api.$web_domain\n#   VITE_REACT_APP_SERVER_WS_BASE_URL=wss://dev.api.$web_domain');
      fs.writeFileSync(f, c);
    " 2>/dev/null || true
    echo "  ✅ Web: Updated .env.example"
  fi

  # Update Web uat.sh and prod.sh scripts default URLs
  web_script_domain="${BRAND_DOMAIN}"
  if [ "$BRAND_NAME" = "RexOne" ]; then
    web_script_domain="rexone.com"
  fi
  if [ -f "$WEB_DIR/scripts/uat.sh" ]; then
    sedi -E "s|https://uat\.api\.[a-zA-Z0-9_.-]+|https://uat.api.${web_script_domain}|g" "$WEB_DIR/scripts/uat.sh"
    sedi -E "s|wss://uat\.api\.[a-zA-Z0-9_.-]+|wss://uat.api.${web_script_domain}|g" "$WEB_DIR/scripts/uat.sh"
    echo "  ✅ Web: Updated scripts/uat.sh target URLs"
  fi
  if [ -f "$WEB_DIR/scripts/prod.sh" ]; then
    sedi -E "s|https://api\.[a-zA-Z0-9_.-]+|https://api.${web_script_domain}|g" "$WEB_DIR/scripts/prod.sh"
    sedi -E "s|wss://api\.[a-zA-Z0-9_.-]+|wss://api.${web_script_domain}|g" "$WEB_DIR/scripts/prod.sh"
    echo "  ✅ Web: Updated scripts/prod.sh target URLs"
  fi

  # Update Web docker-compose.yaml
  if [ -f "$WEB_DIR/docker-compose.yaml" ]; then
    compose_domain="${BRAND_DOMAIN}"
    if [ "$BRAND_NAME" = "RexOne" ]; then
      compose_domain="rexone.com"
    fi
    sedi -E "s|container_name: \\\$\{WEB_CONTAINER_NAME:-[^}]*\}|container_name: \${WEB_CONTAINER_NAME:-prod-${BRAND_SLUG_KEBAB}-web}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|name: \\\$\{DOCKER_NETWORK:-[^}]*\}|name: \${DOCKER_NETWORK:-prod-${BRAND_SLUG_KEBAB}-net}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_NAME: \\\$\{VITE_REACT_APP_NAME:-[^}]*\}|VITE_REACT_APP_NAME: \${VITE_REACT_APP_NAME:-${compose_domain}}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_SERVER_BASE_URL: \\\$\{VITE_REACT_APP_SERVER_BASE_URL:-[^}]*\}|VITE_REACT_APP_SERVER_BASE_URL: \${VITE_REACT_APP_SERVER_BASE_URL:-https://api.${compose_domain}}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_CLIENT_BASE_URL: \\\$\{VITE_REACT_APP_CLIENT_BASE_URL:-[^}]*\}|VITE_REACT_APP_CLIENT_BASE_URL: \${VITE_REACT_APP_CLIENT_BASE_URL:-https://${compose_domain}}|g" "$WEB_DIR/docker-compose.yaml"
    sedi -E "s|VITE_REACT_APP_SERVER_WS_BASE_URL: \\\$\{VITE_REACT_APP_SERVER_WS_BASE_URL:-[^}]*\}|VITE_REACT_APP_SERVER_WS_BASE_URL: \${VITE_REACT_APP_SERVER_WS_BASE_URL:-wss://api.${compose_domain}}|g" "$WEB_DIR/docker-compose.yaml"
    echo "  ✅ Web: Synchronized docker-compose.yaml with prod-${BRAND_SLUG_KEBAB}-web"
  fi

  # Update Web docker-compose.dev.yaml
  if [ -f "$WEB_DIR/docker-compose.dev.yaml" ]; then
    sedi -E "s|container_name: dev-[^ ]*|container_name: dev-${BRAND_SLUG_KEBAB}-web|g" "$WEB_DIR/docker-compose.dev.yaml"
    echo "  ✅ Web: Synchronized docker-compose.dev.yaml (dev-${BRAND_SLUG_KEBAB}-web)"
  fi

  # Update assets/index.ts logo titles and banner
  if [ -f "$WEB_DIR/src/assets/index.ts" ]; then
    banner_alt="${BRAND_NAME} Banner"
    if [ "$BRAND_NAME" = "RexOne" ]; then
      banner_alt="Banner image"
    fi
    sedi -E "s/banner: \{ src: banner, alt: \"[^\"]*\", title: \"[^\"]*\" \}/banner: { src: banner, alt: \"${banner_alt}\", title: \"${BRAND_NAME} Banner\" }/g" "$WEB_DIR/src/assets/index.ts"
    sedi -E "s/logo: \{ src: ([^,]+), alt: \"[^\"]*\", title: \"[^\"]*\" \}/logo: { src: \1, alt: \"${BRAND_NAME} Logo\", title: \"${BRAND_NAME}\" }/g" "$WEB_DIR/src/assets/index.ts"
    sedi -E "s/rexoneLogo: \{ src: ([^,]+), alt: \"[^\"]*\", title: \"[^\"]*\" \}/rexoneLogo: { src: \1, alt: \"${BRAND_NAME} Logo\", title: \"${BRAND_NAME}\" }/g" "$WEB_DIR/src/assets/index.ts"
    echo "  ✅ Web: Synchronized assets/index.ts logo titles"
  fi



  # Update Web notificationRoute helper default origin
  if [ -f "$WEB_DIR/src/modules/notification/helpers/notificationRoute.helper.ts" ]; then
    notif_origin="https://notification.${BRAND_DOMAIN}"
    if [ "$BRAND_NAME" = "RexOne" ]; then
      notif_origin="https://notification.rexone.local"
    fi
    sedi -E "s|https://notification\.[a-zA-Z0-9_.-]+|${notif_origin}|g" "$WEB_DIR/src/modules/notification/helpers/notificationRoute.helper.ts"
    echo "  ✅ Web: Synchronized notificationRoute.helper.ts"
  fi

  # Update Web speech controller and api service comments
  if [ -f "$WEB_DIR/src/services/api.service.ts" ]; then
    sedi -E "s|// .* Core locale|// ${BRAND_NAME} Core locale|g" "$WEB_DIR/src/services/api.service.ts"
  fi
  if [ -f "$WEB_DIR/src/modules/speech/speech.controller.ts" ]; then
    sedi -E "s|using .* Core STT|using ${BRAND_NAME} Core STT|g" "$WEB_DIR/src/modules/speech/speech.controller.ts"
  fi

  # Copy logo if provided
  if [ -n "$RESOLVED_LOGO_PATH" ]; then
    mkdir -p "$WEB_DIR/public/brand"
    cp "$RESOLVED_LOGO_PATH" "$WEB_DIR/public/brand/logo.png"
    if [ "$BRAND_NAME" != "RexOne" ]; then
      cp "$RESOLVED_LOGO_PATH" "$WEB_DIR/public/favicon.png"
    elif [ -f "$WEB_DIR/public/favicon-512x512.png" ]; then
      cp "$WEB_DIR/public/favicon-512x512.png" "$WEB_DIR/public/favicon.png"
    fi
    echo "  ✅ Web: Updated public/brand/logo.png from $(basename "$RESOLVED_LOGO_PATH")"
  fi
  echo "  ℹ️  Web Note: Landing module (src/modules/landing) and SEO assets (index.html, robots.txt, sitemap.xml, llms.txt, llms-full.txt) are intentionally untouched (product SEO & landing are developer responsibility)."
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
    bash "$MOBILE_DIR/scripts/rebrand.sh" "$MOBILE_APP_NAME" "$MOBILE_PACKAGE" "$RESOLVED_LOGO_PATH" "$BRAND_NAME" "$BRAND_DOMAIN" "$RESOLVED_FROM_EMAIL"
  fi
else
  echo "ℹ️  Mobile repository not found at $MOBILE_DIR (skipping)"
fi

echo "============================================================"
echo "🎉 REBRANDING COMPLETED SUCCESSFULLY FOR: $BRAND_NAME"
echo "   Docker Kebab Slug:    $BRAND_SLUG_KEBAB"
echo "   Database Snake Slug:  $BRAND_SLUG_SNAKE"
echo "   Stack Identifiers:    -core, -web, _mobile strictly preserved"
echo "   Foundation: Built on top of the RexOne Ecosystem (rex-9)"
echo "------------------------------------------------------------"
echo "📌 CRITICAL DEVELOPER ACTIONS REQUIRED (SECURITY & SECRETS):"
echo "   1. Environment Files: Live local .env files (.env, .env.dev, etc.)"
echo "      are gitignored and NEVER touched by automation for security."
echo "      Update them manually using synchronized .env.example templates."
echo "   2. Firebase / Google Services: Live credentials (google-services.json"
echo "      and GoogleService-Info.plist) are gitignored and platform-generated."
echo "      Download fresh configuration files from Firebase Console for"
echo "      '$MOBILE_PACKAGE' and place them in android/app/ and ios/Runner/."
echo "   3. Landing Module: Web landing (src/modules/landing) is left intact as"
echo "      it will be completely replaced by whatever product is built on top."
echo "   4. SEO & AI Discovery: RexOne SEO (index.html meta/Schema.org, robots.txt,"
echo "      sitemap.xml, llms.txt, llms-full.txt) is left completely untouched."
echo "      RexOne is the foundation architecture product. Defining product-specific"
echo "      SEO for your product is 100% the developer's responsibility."
echo "   5. Documentation & Policies: All documentation files (README.md,"
echo "      ECOSYSTEM.md, CODE_OF_CONDUCT.md, COMMUNITY_STANDARDS.md, docs/*)"
echo "      are intentionally left untouched. New products require their own"
echo "      documentation; documenting derivative products is 100% developer"
echo "      responsibility."
echo "============================================================"
