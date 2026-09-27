#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ $# -eq 2 ]]; then
  EMAIL="${1:-}"
  USERNAME=""
  PASSWORD="${2:-}"
elif [[ $# -ge 3 ]]; then
  EMAIL="${1:-}"
  USERNAME="${2:-}"
  PASSWORD="${3:-}"
else
  echo "Usage: ./scripts/seed_super_admin.sh <email> <username> <password>"
  echo "   or: ./scripts/seed_super_admin.sh <email> <password>"
  exit 1
fi

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "Error: Email and password are required"
  echo "Usage: ./scripts/seed_super_admin.sh <email> <username> <password>"
  exit 1
fi

docker compose -f docker-compose.dev.yaml exec -T \
  -e SEED_SUPER_ADMIN_EMAIL="$EMAIL" \
  -e SEED_SUPER_ADMIN_USERNAME="$USERNAME" \
  -e SEED_SUPER_ADMIN_PASSWORD="$PASSWORD" \
  api rails runner - <<'RUBY'
email = ENV.fetch("SEED_SUPER_ADMIN_EMAIL").downcase.strip
username = ENV["SEED_SUPER_ADMIN_USERNAME"].to_s.downcase.strip.presence
password = ENV.fetch("SEED_SUPER_ADMIN_PASSWORD")

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
end

user.password = password
user.password_confirmation = password
user.confirmed_at ||= Time.current
user.save!

Iam::UserRole.find_or_create_by!(user: user, role: role)

puts "✅ Super admin ready: #{user.email}"
puts "   Username: #{user.username}"
puts "   Role: #{role.name}"
RUBY
