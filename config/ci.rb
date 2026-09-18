# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Locales: Parity & Interpolations", "./scripts/check_locales.sh"

  step "Autoload: Zeitwerk", "bin/rails zeitwerk:check"

  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "OpenAPI: Swaggerize", "bundle exec rake rswag:specs:swaggerize"

  step "Tests: RSpec", "bundle exec rspec --tag ~type:system --tag ~e2e"

  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
