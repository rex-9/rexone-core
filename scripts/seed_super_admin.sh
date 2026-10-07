#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

EMAIL="${1:-}"
PASSWORD="${2:-}"
USERNAME="${3:-}"

if [[ $# -eq 0 ]]; then
  if [[ -f .env ]]; then
    EMAIL="$(grep -E '^SEED_SUPER_ADMIN_EMAIL=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
    PASSWORD="$(grep -E '^SEED_SUPER_ADMIN_PASSWORD=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
    USERNAME="$(grep -E '^SEED_SUPER_ADMIN_USERNAME=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
  fi
  EMAIL="${EMAIL:-${SEED_SUPER_ADMIN_EMAIL:-}}"
  PASSWORD="${PASSWORD:-${SEED_SUPER_ADMIN_PASSWORD:-}}"
  USERNAME="${USERNAME:-${SEED_SUPER_ADMIN_USERNAME:-}}"
elif [[ $# -eq 1 ]]; then
  EMAIL="${1:-}"
  if [[ -f .env ]]; then
    PASSWORD="$(grep -E '^SEED_SUPER_ADMIN_PASSWORD=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
    USERNAME="$(grep -E '^SEED_SUPER_ADMIN_USERNAME=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
  fi
  PASSWORD="${PASSWORD:-${SEED_SUPER_ADMIN_PASSWORD:-}}"
  USERNAME="${USERNAME:-${SEED_SUPER_ADMIN_USERNAME:-}}"
elif [[ $# -eq 2 ]]; then
  EMAIL="${1:-}"
  PASSWORD="${2:-}"
  if [[ -f .env ]]; then
    USERNAME="$(grep -E '^SEED_SUPER_ADMIN_USERNAME=' .env | head -n1 | cut -d'=' -f2- | tr -d '\r\n\"'\'' ' || true)"
  fi
  USERNAME="${USERNAME:-${SEED_SUPER_ADMIN_USERNAME:-}}"
elif [[ $# -ge 3 ]]; then
  EMAIL="${1:-}"
  PASSWORD="${2:-}"
  USERNAME="${3:-}"
fi

if [[ -z "$EMAIL" || -z "$PASSWORD" || "$PASSWORD" == changeme_* ]]; then
  echo "❌ Error: SEED_SUPER_ADMIN_EMAIL and a valid non-placeholder password are required."
  echo "Usage: ./scripts/seed_super_admin.sh [email] [password] [username]"
  echo "   or: ./scripts/seed_super_admin.sh [email] [password]"
  echo "   or: ./scripts/seed_super_admin.sh (reads SEED_SUPER_ADMIN_* from .env)"
  exit 1
fi

COMPOSE_FILE="docker-compose.dev.yaml"
if [[ ! -f "$COMPOSE_FILE" ]] || ! docker compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | grep -q "^api$"; then
  if [[ -f "docker-compose.yaml" ]] && docker compose -f "docker-compose.yaml" ps --services --filter "status=running" 2>/dev/null | grep -q "^api$"; then
    COMPOSE_FILE="docker-compose.yaml"
  fi
fi

RUBY_SCRIPT='
email = ENV.fetch("SEED_SUPER_ADMIN_EMAIL").downcase.strip
password = ENV.fetch("SEED_SUPER_ADMIN_PASSWORD")
username = ENV["SEED_SUPER_ADMIN_USERNAME"].to_s.downcase.strip.presence

raise "Email is required" if email.blank?
raise "Password must be at least 6 characters" if password.length < 6

if username.present?
  raise "Username must be 3-30 characters (lowercase letters, numbers, and underscores)" unless username.match?(/\A[a-z0-9_]{3,30}\z/)
end

role = Iam::Role.find_by!(name: IamConstants::Role::SUPER_ADMIN)

user = User.find_or_initialize_by(email: email)
if user.new_record?
  user.username = username || "super_admin_#{SecureRandom.hex(4)}"
  user.name = "Super Admin"
elsif username.present?
  user.username = username
elsif user.username.blank?
  user.username = "super_admin_#{SecureRandom.hex(4)}"
end

user.password = password
user.password_confirmation = password
user.confirmed_at ||= Time.current
user.save!

Iam::UserRole.find_or_create_by!(user: user, role: role)

puts "✅ Super admin ready: #{user.email}"
puts "   Username: #{user.username}"
puts "   Role: #{role.name}"
puts "   Admin Portal Login: username '\''#{user.username}'\'' with your password"
'

if docker compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | grep -q "^api$"; then
  docker compose -f "$COMPOSE_FILE" exec -T \
    -e SEED_SUPER_ADMIN_EMAIL="$EMAIL" \
    -e SEED_SUPER_ADMIN_USERNAME="$USERNAME" \
    -e SEED_SUPER_ADMIN_PASSWORD="$PASSWORD" \
    api rails runner "$RUBY_SCRIPT"
else
  echo "ℹ️  Container 'api' is not running. Starting one-off runner container..."
  docker compose -f "$COMPOSE_FILE" run --rm \
    -e SEED_SUPER_ADMIN_EMAIL="$EMAIL" \
    -e SEED_SUPER_ADMIN_USERNAME="$USERNAME" \
    -e SEED_SUPER_ADMIN_PASSWORD="$PASSWORD" \
    api rails runner "$RUBY_SCRIPT"
fi
