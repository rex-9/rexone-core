module AppConfig
  # Keys & Tokens
  SECRET_KEY_BASE = ENV.fetch("RAILS_SECRET_KEY_BASE") { "secret-key-base" }
  MASTER_KEY = ENV.fetch("RAILS_MASTER_KEY") { "master-key" }
  JWT_SECRET_KEY = ENV.fetch("RAILS_JWT_SECRET_KEY") { "rexone" }
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  # Client & Server urls
  CLIENT_BASE_URL = ENV.fetch("RAILS_CLIENT_BASE_URL") { "http://localhost:4000" }
  SERVER_BASE_URL = ENV.fetch("RAILS_SERVER_BASE_URL") { "http://localhost:3000" }

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

  # Speech
  SPEECH_SERVICE_BASE_URL = ENV.fetch("SPEECH_SERVICE_BASE_URL")
  SPEECH_TTS_ENDPOINT_PATH = ENV.fetch("SPEECH_TTS_ENDPOINT_PATH", "/ssml-to-speech")
  SPEECH_STT_ENDPOINT_PATH = ENV.fetch("SPEECH_STT_ENDPOINT_PATH", "/speech-to-text")

  # Session & token timeouts
  SESSION_TIMEOUT = ENV.fetch("SESSION_TIMEOUT") { 1.week }.to_i.seconds # 7-day maximum login, Cache Active Platform Session Lifespan
  JWT_EXPIRATION = ENV.fetch("JWT_EXPIRATION") { 1.week }.to_i.seconds #  7-day inactivity timeout, JWT Token Expiration Lifespan

  # Password reset
  PASSWORD_RESET_WITHIN = ENV.fetch("PASSWORD_RESET_WITHIN") { 1.hour }.to_i.seconds

  # Unconfirmed access
  ALLOW_UNCONFIRMED_ACCESS_FOR = ENV.fetch("ALLOW_UNCONFIRMED_ACCESS_FOR") { 1.day }.to_i.seconds

  # Confirm code before
  CONFIRM_CODE_WITHIN = ENV.fetch("CONFIRM_CODE_WITHIN") { 10.minutes }.to_i.seconds

  # Confirm code before
  SOLID_QUEUE_SHUTDOWN_TIMEOUT = ENV.fetch("SOLID_QUEUE_SHUTDOWN_TIMEOUT") { 30.seconds }.to_i.seconds
end
