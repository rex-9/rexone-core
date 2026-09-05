module AppConfig
  # Helper to resolve non-empty env strings with fallbacks (no external gem dependency required)
  env_or = ->(key, fallback = nil) {
    val = ENV[key]
    (val.nil? || val.strip.empty?) ? fallback : val
  }

  # Keys & Tokens
  SECRET_KEY_BASE = env_or.call("RAILS_SECRET_KEY_BASE") || env_or.call("SECRET_KEY_BASE") || "secret-key-base"
  MASTER_KEY = env_or.call("RAILS_MASTER_KEY") || env_or.call("MASTER_KEY") || "master-key"
  JWT_SECRET_KEY = env_or.call("RAILS_JWT_SECRET_KEY", "rexone")
  JWT_TOKEN = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  # Server & Environment
  RAILS_ENV = env_or.call("RAILS_ENV", "development")
  RAILS_LOG_LEVEL = env_or.call("RAILS_LOG_LEVEL", "info")
  RAILS_MAX_THREADS = env_or.call("RAILS_MAX_THREADS", "7").to_i
  RAILS_SERVER_HOST = env_or.call("RAILS_SERVER_HOST", "localhost")
  PORT = env_or.call("PORT", "3000").to_i
  DB_POOL = env_or.call("DB_POOL", RAILS_MAX_THREADS.to_s).to_i
  CI = !env_or.call("CI").nil?

  # Client & Server urls
  CLIENT_BASE_URL = env_or.call("RAILS_CLIENT_BASE_URL", "http://localhost:4000")
  SERVER_BASE_URL = env_or.call("RAILS_SERVER_BASE_URL", "http://localhost:3000")

  # Email / SMTP
  SMTP_ADDRESS = env_or.call("SMTP_ADDRESS", "smtp.gmail.com")
  SMTP_PORT = env_or.call("SMTP_PORT", "587").to_i
  SMTP_DOMAIN = env_or.call("SMTP_DOMAIN", "rexone.me")
  SMTP_USERNAME = env_or.call("SMTP_USERNAME", "")
  SMTP_PASSWORD = env_or.call("SMTP_PASSWORD", "")
  FROM_EMAIL = env_or.call("FROM_EMAIL", "support@rexone.me")

  # Stripe Keys
  STRIPE_SECRET_KEY = env_or.call("STRIPE_SECRET_KEY", "")
  STRIPE_PUBLISHABLE_KEY = env_or.call("STRIPE_PUBLISHABLE_KEY", "")
  STRIPE_WEBHOOK_SECRET = env_or.call("STRIPE_WEBHOOK_SECRET", "")
  STRIPE_SUCCESS_URL = env_or.call("STRIPE_SUCCESS_URL", "http://localhost:4000/success")
  STRIPE_CANCEL_URL = env_or.call("STRIPE_CANCEL_URL", "http://localhost:4000/cancel")

  # Onesignal Keys
  ONE_SIGNAL_APP_ID = env_or.call("ONE_SIGNAL_APP_ID", "")
  ONE_SIGNAL_API_KEY = env_or.call("ONE_SIGNAL_API_KEY", "")
  ONE_SIGNAL_DEFAULT_SOUND = env_or.call("ONE_SIGNAL_DEFAULT_SOUND", "default")

  # DeepSeek Keys
  DEEPSEEK_API_KEY = env_or.call("DEEPSEEK_API_KEY", "")
  DEEPSEEK_BASE_URL = env_or.call("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
  DEEPSEEK_MODEL = env_or.call("DEEPSEEK_MODEL", "deepseek-v4-flash")

  # Speech
  SPEECH_SERVICE_BASE_URL = env_or.call("SPEECH_SERVICE_BASE_URL", "")
  SPEECH_TTS_ENDPOINT_PATH = env_or.call("SPEECH_TTS_ENDPOINT_PATH", "/ssml-to-speech")
  SPEECH_STT_ENDPOINT_PATH = env_or.call("SPEECH_STT_ENDPOINT_PATH", "/speech-to-text")
  AZURE_SPEECH_KEY = env_or.call("AZURE_SPEECH_KEY", "")
  AZURE_SPEECH_REGION = env_or.call("AZURE_SPEECH_REGION", "southeastasia")
  AZURE_SPEECH_LANGUAGE = env_or.call("AZURE_SPEECH_LANGUAGE", "en-US")
  AZURE_SPEECH_VOICE = env_or.call("AZURE_SPEECH_VOICE", "en-US-AvaNeural")

  # Session & token timeouts (seconds / Duration)
  SESSION_TIMEOUT = env_or.call("SESSION_TIMEOUT", (7 * 24 * 60 * 60).to_s).to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }
  JWT_EXPIRATION = env_or.call("JWT_EXPIRATION", (7 * 24 * 60 * 60).to_s).to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }
  PASSWORD_RESET_WITHIN = env_or.call("PASSWORD_RESET_WITHIN", (60 * 60).to_s).to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }
  ALLOW_UNCONFIRMED_ACCESS_FOR = env_or.call("ALLOW_UNCONFIRMED_ACCESS_FOR", (24 * 60 * 60).to_s).to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }
  CONFIRM_CODE_WITHIN = env_or.call("CONFIRM_CODE_WITHIN", (10 * 60).to_s).to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }

  # Solid Queue Worker
  SOLID_QUEUE_IN_PUMA = !env_or.call("SOLID_QUEUE_IN_PUMA").nil? && env_or.call("SOLID_QUEUE_IN_PUMA") != "0" && env_or.call("SOLID_QUEUE_IN_PUMA") != "false"
  SOLID_QUEUE_SHUTDOWN_TIMEOUT = env_or.call("SOLID_QUEUE_SHUTDOWN_TIMEOUT", "30").to_i.then { |s| defined?(ActiveSupport) ? s.seconds : s }
  PIDFILE = env_or.call("PIDFILE", nil)

  # Storage Provider (garage, cloudinary, local)
  STORAGE_PROVIDER = env_or.call("STORAGE_PROVIDER", "garage")

  # Garage S3 Object Storage
  S3_BUCKET = env_or.call("S3_BUCKET", "rexone")
  S3_ENDPOINT = env_or.call("S3_ENDPOINT", "http://garage:3100")
  S3_PUBLIC_ENDPOINT = env_or.call("S3_PUBLIC_ENDPOINT", "http://localhost:3100")
  S3_REGION = env_or.call("S3_REGION", "garage")
  S3_ACCESS_KEY = env_or.call("S3_ACCESS_KEY", "")
  s3_raw_secret = env_or.call("S3_SECRET_KEY", "")
  if s3_raw_secret =~ /\A([0-9a-f]{64})/i
    S3_SECRET_KEY = $1
  else
    S3_SECRET_KEY = s3_raw_secret
  end

  s3_admin_ep = env_or.call("S3_ADMIN_ENDPOINT")
  if s3_admin_ep.nil? && s3_raw_secret =~ /S3_ADMIN_ENDPOINT=([^\s]+)/
    s3_admin_ep = $1
  end
  S3_ADMIN_ENDPOINT = s3_admin_ep || "http://garage:3101"
  S3_ADMIN_TOKEN = env_or.call("S3_ADMIN_TOKEN", nil)

  # Cloudinary Storage
  CLOUDINARY_CLOUD_NAME = env_or.call("CLOUDINARY_CLOUD_NAME", "")
  CLOUDINARY_API_KEY = env_or.call("CLOUDINARY_API_KEY", "")
  CLOUDINARY_API_SECRET = env_or.call("CLOUDINARY_API_SECRET", "")

  # Local Storage
  LOCAL_STORAGE_PATH = env_or.call("LOCAL_STORAGE_PATH", File.expand_path("../../storage", __dir__))

  # Media Compression & Worker Pipeline
  MEDIA_CONTAINER_ENABLED = env_or.call("MEDIA_CONTAINER_ENABLED", "true") == "true"
  GARAGE_CONTAINER_ENABLED = env_or.call("GARAGE_CONTAINER_ENABLED", "true") == "true"
  MEDIA_MAX_VIDEO_SIZE_MB = env_or.call("MEDIA_MAX_VIDEO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "100" : "10").to_i
  MEDIA_MAX_NON_VIDEO_SIZE_MB = env_or.call("MEDIA_MAX_NON_VIDEO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "10" : "1").to_i
  MEDIA_VIDEO_CRF = env_or.call("MEDIA_VIDEO_CRF", "23").to_i
  MEDIA_VIDEO_PRESET = env_or.call("MEDIA_VIDEO_PRESET", "medium").freeze
  MEDIA_VIDEO_MAX_WIDTH = env_or.call("MEDIA_VIDEO_MAX_WIDTH", "1920").to_i
  MEDIA_VIDEO_MAX_HEIGHT = env_or.call("MEDIA_VIDEO_MAX_HEIGHT", "1080").to_i
  MEDIA_VIDEO_MAX_BITRATE = env_or.call("MEDIA_VIDEO_MAX_BITRATE", "5M").freeze
  MEDIA_VIDEO_BUFFER_SIZE = env_or.call("MEDIA_VIDEO_BUFFER_SIZE", "10M").freeze
  MEDIA_VIDEO_AUDIO_BITRATE = env_or.call("MEDIA_VIDEO_AUDIO_BITRATE", "128k").freeze
  MEDIA_VIDEO_CODEC = env_or.call("MEDIA_VIDEO_CODEC", "libx264").freeze
  MEDIA_VIDEO_AUDIO_CODEC = env_or.call("MEDIA_VIDEO_AUDIO_CODEC", "aac").freeze
  MEDIA_IMAGE_JPEG_QUALITY = env_or.call("MEDIA_IMAGE_JPEG_QUALITY", "82").to_i
  MEDIA_IMAGE_PNG_QUALITY = env_or.call("MEDIA_IMAGE_PNG_QUALITY", "82").to_i
  MEDIA_IMAGE_PNG_COMPRESSION = env_or.call("MEDIA_IMAGE_PNG_COMPRESSION", "9").to_i
  MEDIA_IMAGE_WEBP_QUALITY = env_or.call("MEDIA_IMAGE_WEBP_QUALITY", "80").to_i
  MEDIA_IMAGE_MAX_WIDTH = env_or.call("MEDIA_IMAGE_MAX_WIDTH", "1920").to_i
  MEDIA_IMAGE_MAX_HEIGHT = env_or.call("MEDIA_IMAGE_MAX_HEIGHT", "1080").to_i
  MEDIA_MAX_COMPRESSION_PASSES = env_or.call("MEDIA_MAX_COMPRESSION_PASSES", "2").to_i

  # Telemetry & Observability (Rails Error Dashboard)
  DASHBOARD_BASE_URL = env_or.call("DASHBOARD_BASE_URL", nil)
  APP_VERSION = env_or.call("APP_VERSION", nil)
  GIT_SHA = env_or.call("GIT_SHA", nil)
end
