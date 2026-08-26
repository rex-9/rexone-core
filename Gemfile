source "https://rubygems.org"

# ============================================================
# Rails
# ============================================================

gem "psych", "~> 5.4.0"
# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 8.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# ============================================================
# Solid Stack
# ============================================================

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "async", "~> 2.44"

# ============================================================
# Performance / Deployment
# ============================================================

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# ============================================================
# Assets / Media
# ============================================================

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"
gem "ruby-vips", "~> 2.3"

# ============================================================
# Admin Dashboards / Monitoring
# ============================================================

gem "administrate", "~> 1.0"
gem "sprockets-rails", "~> 3.5"
gem "sassc-rails", "~> 2.1"
gem "csv", "~> 3.3"

gem "rails_pulse", "~> 0.3.3"
gem "rails_error_dashboard", "~> 0.8.3" # Alternatives: rails_error_dashboard, faultline, https://github.com/dkam/splat
gem "solid_web_ui", "~> 0.4.0" # Alternatives: mission_control-jobs, solid_observer, solid_queue_monitor

# ============================================================
# Authentication / Authorization
# ============================================================

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1"
gem "devise", "~> 5.0"
gem "devise-jwt", "~> 0.13.0"
gem "jwt", "~> 3.2"

# ============================================================
# API / Serialization
# ============================================================

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors", "~> 3.0"
gem "jsonapi-serializer", "~> 2.2"
gem "rest-client", "~> 2.1"
gem "rswag", "~> 2.17"

# ============================================================
# Security
# ============================================================

gem "rack-attack", "~> 6.8"

# ============================================================
# External Services
# ============================================================

gem "cloudinary", "~> 2.4"
gem "stripe", "~> 19.5"
gem "websocket-client-simple", "~> 0.9"

# ============================================================
# Utilities
# ============================================================

gem "pagy", "~> 43.6"

# ============================================================
# Development / Test
# ============================================================

group :development, :test do
  # Ruby debugging tool
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  # Scan gems for security vulnerabilities
  gem "bundler-audit", require: false
  # Static analysis vulnerability scanner
  gem "brakeman", require: false
  # Linting and code style compliance
  gem "rubocop-rails-omakase", require: false
  # Behavior-driven development testing framework
  gem "rspec-rails", "~> 8.0"
  # Test fixture replacement for generating test data
  gem "factory_bot_rails", "~> 6.5"
  # One-liner testing helpers for Rails functionality
  gem "shoulda-matchers", "~> 8.0"
  # Generate realistic fake data for testing
  gem "faker", "~> 3.8"
  # Ensure a clean database state between tests
  gem "database_cleaner-active_record", "~> 2.2"
  # Load environment variables from .env files
  gem "dotenv-rails", "~> 3.2"
  # Automatically run RSpec tests when files change
  gem "guard-rspec", "~> 4.7"
end

group :development do
  gem "solargraph", "~> 0.60.2"
end

gem "discard", "~> 2.0"
