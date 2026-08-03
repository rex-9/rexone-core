module AppConfig
  # Keys & Tokens
  SECRET_KEY_BASE = ENV.fetch("RAILS_SECRET_KEY_BASE") { "secret-key-base" }
  MASTER_KEY = ENV.fetch("RAILS_MASTER_KEY") { "master-key" }
  JWT_SECRET_KEY = ENV.fetch("RAILS_JWT_SECRET_KEY") { "meritbox-me" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  # Client & Server urls
  CLIENT_BASE_URL = ENV.fetch("RAILS_CLIENT_BASE_URL") { "http://localhost:4002" }
  SERVER_BASE_URL = ENV.fetch("RAILS_SERVER_BASE_URL") { "http://localhost:3000" }

  # Administrate creds
  RAILS_ADMIN_USERNAME = ENV.fetch("RAILS_ADMIN_USERNAME")
  RAILS_ADMIN_PASSWORD = ENV.fetch("RAILS_ADMIN_PASSWORD")

  # Stripe Keys
  STRIPE_SECRET_KEY = ENV.fetch("STRIPE_SECRET_KEY")
  STRIPE_PUBLISHABLE_KEY = ENV.fetch("STRIPE_PUBLISHABLE_KEY")
  STRIPE_WEBHOOK_SECRET = ENV.fetch("STRIPE_WEBHOOK_SECRET")
  STRIPE_SUCCESS_URL = ENV.fetch("STRIPE_SUCCESS_URL")
  STRIPE_CANCEL_URL = ENV.fetch("STRIPE_CANCEL_URL")

  # Onesignal Keys
  ONE_SIGNAL_APP_ID = ENV.fetch("ONE_SIGNAL_APP_ID")
  ONE_SIGNAL_API_KEY = ENV.fetch("ONE_SIGNAL_API_KEY")
  ONE_SIGNAL_DEFAULT_SOUND = ENV.fetch("ONE_SIGNAL_DEFAULT_SOUND")
  FROM_EMAIL = ENV.fetch("FROM_EMAIL")

  # DeepSeek Keys
  DEEPSEEK_API_KEY=ENV.fetch("DEEPSEEK_API_KEY")
  DEEPSEEK_BASE_URL=ENV.fetch("DEEPSEEK_BASE_URL")
  DEEPSEEK_MODEL=ENV.fetch("DEEPSEEK_MODEL")

  # Session & token timeouts
  SESSION_TIMEOUT = 1.week
  JWT_EXPIRATION = 1.week

  # Password reset
  PASSWORD_RESET_WITHIN = 6.hours

  # Confirm code before
  CONFIRM_CODE_WITHIN = 10.minutes

  # Unconfirmed access
  ALLOW_UNCONFIRMED_ACCESS_FOR = 2.days

  # Rack::Attack
  RACK_ATTACK_CACHE_EXPIRY = 10.minutes
end
