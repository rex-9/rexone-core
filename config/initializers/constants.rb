module AppConfig
  SECRET_KEY_BASE = ENV.fetch("RAILS_APP_SECRET_KEY_BASE")
  JWT_SECRET_KEY = ENV.fetch("RAILS_APP_JWT_SECRET_KEY") { "auth-service" }
  CLIENT_BASE_URL = ENV.fetch("RAILS_APP_CLIENT_BASE_URL") { "http://localhost:5173" }
  SERVER_BASE_URL = ENV.fetch("RAILS_APP_SERVER_BASE_URL") { "http://localhost:3000" }
  GOOGLE_CLIENT_ID = ENV.fetch("RAILS_APP_GOOGLE_CLIENT_ID") { "1026550055658-skeaoo2ipej0ntv2i5vtj3s7isgdhqg4.apps.googleusercontent.com" }
  GOOGLE_CLIENT_SECRET = ENV.fetch("RAILS_APP_GOOGLE_CLIENT_SECRET") { "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" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
end
