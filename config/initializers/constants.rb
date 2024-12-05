module AppConfig
  SECRET_KEY_BASE = ENV.fetch("RAILS_SECRET_KEY_BASE") { "secret-key-base" }
  MASTER_KEY = ENV.fetch("RAILS_MASTER_KEY") { "master-key" }
  JWT_SECRET_KEY = ENV.fetch("RAILS_JWT_SECRET_KEY") { "auth-service" }
  CLIENT_BASE_URL = ENV.fetch("RAILS_CLIENT_BASE_URL") { "http://localhost:5173" }
  SERVER_BASE_URL = ENV.fetch("RAILS_SERVER_BASE_URL") { "http://localhost:3000" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
end
