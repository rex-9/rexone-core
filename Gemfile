source "https://rubygems.org"

gem "psych", "~> 5.2.6"
# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 8.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec is a testing tool for Ruby, created for behavior-driven development (BDD) [https://rspec.info/]
  gem "rspec-rails", "~> 8.0"

  # FactoryBot is a fixtures replacement with a straightforward definition syntax, support for multiple build strategies (saved instances, unsaved instances, attribute hashes, and stubbed objects), and support for multiple factories for the same class (user, admin_user, and so on), including factory inheritance [
  gem "factory_bot_rails", "~> 6.5"

  # RSpec- and Minitest-compatible one-liners to test common Rails functionality [https://github.com/thoughtbot/shoulda-matchers]
  gem "shoulda-matchers", "~> 7.0"

  # Library for generating fake data such as names, addresses, and phone numbers. [https://github.com/faker-ruby/faker]
  gem "faker", "~> 3.8"

  gem "database_cleaner-active_record", "~> 2.2"
  gem "solargraph", "~> 0.60.2"
  gem "dotenv-rails", "~> 3.2"
end

gem "redis", "~> 5.4"

gem "bcrypt", "~> 3.1"

gem "jwt", "~> 3.2"

gem "rack-cors", "~> 3.0"

gem "rest-client", "~> 2.1"

gem "devise", "~> 5.0"

gem "devise-jwt", "~> 0.13.0"

gem "jsonapi-serializer", "~> 2.2"

gem "rswag", "~> 2.17"

gem "rails_performance", "~> 1.6"

gem "rack-attack", "~> 6.8"

gem "cloudinary", "~> 2.4"

gem "rails_admin", "~> 3.3"
gem "sprockets-rails", "~> 3.5"
gem "sassc-rails"
