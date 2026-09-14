#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

EMAIL="${1:-}"
PASSWORD="${2:-}"

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "Usage: ./scripts/seed_super_admin.sh <email> <password>"
  exit 1
fi

docker compose -f docker-compose.dev.yaml exec -T \
  -e SEED_SUPER_ADMIN_EMAIL="$EMAIL" \
  -e SEED_SUPER_ADMIN_PASSWORD="$PASSWORD" \
  api rails runner - <<'RUBY'
email = ENV.fetch("SEED_SUPER_ADMIN_EMAIL").downcase.strip
password = ENV.fetch("SEED_SUPER_ADMIN_PASSWORD")

raise "Email is required" if email.blank?
raise "Password must be at least 6 characters" if password.length < 6

role = Iam::Role.find_by!(name: IamConstants::Role::SUPER_ADMIN)

user = User.find_or_initialize_by(email: email)
if user.new_record?
  suffix = SecureRandom.hex(4)
  user.username = "super_admin_#{suffix}"
  user.name = "Super Admin"
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
