require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MeritboxApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    config.time_zone = "UTC"  # Set a consistent timezone
    config.active_record.default_timezone = :utc

    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    Rails.application.config.secret_key_base = Rails.application.credentials.secret_key_base

    # Enable Flash, Cookies, MethodOverride for Administrate Gem
    config.middleware.use ActionDispatch::Flash
    config.session_store :cookie_store
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options
    config.middleware.use ::Rack::MethodOverride

    # ---- Solid Stack ----
    # Use Solid Queue as the default Active Job adapter
    config.active_job.queue_adapter = :solid_queue

    # Use Solid Cache as the default cache store
    config.cache_store = :solid_cache_store

    # Enable fiber isolation if you plan to use fibers in jobs (recommended)
    # This allows Active Support to maintain per-fiber state
    config.active_support.isolation_level = :fiber

    # Optional: If you use multiple databases, you can specify a separate
    # database for Solid Cache and Solid Queue, but for simplicity we use
    # the primary one.
  end
end
