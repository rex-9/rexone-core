module AppConfig
  SECRET_KEY_BASE = ENV.fetch("RAILS_APP_SECRET_KEY_BASE") { "secret-key-base" }
  JWT_SECRET_KEY = ENV.fetch("RAILS_APP_JWT_SECRET_KEY") { "auth-service" }
  CLIENT_BASE_URL = ENV.fetch("RAILS_APP_CLIENT_BASE_URL") { "http://localhost:5173" }
  SERVER_BASE_URL = ENV.fetch("RAILS_APP_SERVER_BASE_URL") { "http://localhost:3000" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
end
