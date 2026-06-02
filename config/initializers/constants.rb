module AppConfig
  # Keys & Tokens
  SECRET_KEY_BASE = ENV.fetch("RAILS_SECRET_KEY_BASE") { "secret-key-base" }
  MASTER_KEY = ENV.fetch("RAILS_MASTER_KEY") { "master-key" }
  JWT_SECRET_KEY = ENV.fetch("RAILS_JWT_SECRET_KEY") { "meritbox-me" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  # Client & Server urls
  CLIENT_BASE_URL = ENV.fetch("RAILS_CLIENT_BASE_URL") { "http://localhost:4002" }
  SERVER_BASE_URL = ENV.fetch("RAILS_SERVER_BASE_URL") { "http://localhost:3000" }

  # Session & token timeouts
  SESSION_TIMEOUT = 1.week
  JWT_EXPIRATION = 1.week

  # Password reset
  PASSWORD_RESET_WITHIN = 6.hours

  # Unconfirmed access
  ALLOW_UNCONFIRMED_ACCESS_FOR = 2.days
end
