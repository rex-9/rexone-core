# frozen_string_literal: true

# config/app_config.rb
# ==============================================================================
# 🏛️ RexOne Core Centralized Application Configuration (Law U2 & Law U14)
# ==============================================================================
# Single source of truth for all environment variables, system timeouts, third-party
# provider keys, and hardware concurrency limits.
#
# Access strictly via typed, frozen constants:
#   AppConfig::PORT, AppConfig::CLIENT_BASE_URL, AppConfig::PRODUCT_DOMAIN
# ==============================================================================

begin
  require "active_support/core_ext/integer/time"
rescue LoadError
  # Running in minimal context without active_support loaded
end

module AppConfig
  # Helper to resolve non-empty env strings with fallbacks (no external gem dependency)
  env_or = ->(key, fallback = nil) {
    val = ENV[key]
    (val.nil? || val.strip.empty?) ? fallback : val.strip
  }

  # ----------------------------------------------------------------------------
  # 🔐 Security, Identity & Cryptography
  # ----------------------------------------------------------------------------
  SECRET_KEY_BASE              = env_or.call("RAILS_SECRET_KEY_BASE") || env_or.call("SECRET_KEY_BASE") || "secret-key-base"
  MASTER_KEY                  = env_or.call("RAILS_MASTER_KEY") || env_or.call("MASTER_KEY") || "master-key"
  JWT_SECRET_KEY              = env_or.call("RAILS_JWT_SECRET_KEY", "rexone")
  JWT_TOKEN                   = ->(user) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  # ----------------------------------------------------------------------------
  # 🌐 Server, Networking & Domains
  # ----------------------------------------------------------------------------
  RAILS_ENV                   = env_or.call("RAILS_ENV", "development")
  RAILS_LOG_LEVEL             = env_or.call("RAILS_LOG_LEVEL", "info")
  PORT                        = env_or.call("PORT", "3000").to_i
  RAILS_SERVER_HOST           = env_or.call("RAILS_SERVER_HOST", "localhost")
  SERVER_BASE_URL             = env_or.call("RAILS_SERVER_BASE_URL", "http://localhost:3000")
  CLIENT_BASE_URL             = env_or.call("RAILS_CLIENT_BASE_URL", "http://localhost:4000")
  PRODUCT_DOMAIN              = env_or.call("PRODUCT_DOMAIN", nil)
  SERVER_TIMEZONE             = env_or.call("RAILS_TIMEZONE", "UTC").freeze
  CORS_ORIGINS                = env_or.call("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?).freeze
  CORS_ALLOW_LOCALHOST        = env_or.call("CORS_ALLOW_LOCALHOST") == "true"
  CI                          = !env_or.call("CI").nil?

  # ----------------------------------------------------------------------------
  # 🗄️ Database & Connection Pooling
  # ----------------------------------------------------------------------------
  RAILS_MAX_THREADS           = env_or.call("RAILS_MAX_THREADS", "7").to_i
  DB_POOL                     = env_or.call("DB_POOL", RAILS_MAX_THREADS.to_s).to_i
  DATABASE_URL                = env_or.call("RAILS_DATABASE_URL") || env_or.call("DATABASE_URL")
  TEST_DATABASE_URL           = env_or.call("RAILS_TEST_DATABASE_URL") || DATABASE_URL&.sub(%r{/[^/]+\z}, "/rexone_core_test")

  # ----------------------------------------------------------------------------
  # ⚡ Solid Queue, Concurrency & Workers
  # ----------------------------------------------------------------------------
  WEB_CONCURRENCY             = env_or.call("WEB_CONCURRENCY", "1")
  SOLID_QUEUE_IN_PUMA         = !env_or.call("SOLID_QUEUE_IN_PUMA").nil? && env_or.call("SOLID_QUEUE_IN_PUMA") != "0" && env_or.call("SOLID_QUEUE_IN_PUMA") != "false"
  SOLID_QUEUE_SHUTDOWN_TIMEOUT = env_or.call("SOLID_QUEUE_SHUTDOWN_TIMEOUT", "30").to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }
  SOLID_QUEUE_FIBERS          = env_or.call("SOLID_QUEUE_FIBERS", "50").to_i
  SOLID_QUEUE_POLLING_INTERVAL = env_or.call("SOLID_QUEUE_POLLING_INTERVAL", "0.1").to_f
  SOLID_QUEUE_MAINTENANCE_THREADS = env_or.call("SOLID_QUEUE_MAINTENANCE_THREADS", "2").to_i
  MEDIA_QUEUE_THREADS         = env_or.call("MEDIA_QUEUE_THREADS", "2").to_i
  DATA_SYNC_SCHEDULE          = env_or.call("DATA_SYNC_SCHEDULE", "at 3:00am every Sunday")
  PIDFILE                     = env_or.call("PIDFILE", nil)

  # ----------------------------------------------------------------------------
  # ⏱️ Session Lifecycles & Security Timeouts
  # ----------------------------------------------------------------------------
  SESSION_TIMEOUT             = env_or.call("SESSION_TIMEOUT", (7 * 24 * 60 * 60).to_s).to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }
  JWT_EXPIRATION              = env_or.call("JWT_EXPIRATION", (7 * 24 * 60 * 60).to_s).to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }
  PASSWORD_RESET_WITHIN       = env_or.call("PASSWORD_RESET_WITHIN", (60 * 60).to_s).to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }
  ALLOW_UNCONFIRMED_ACCESS_FOR = env_or.call("ALLOW_UNCONFIRMED_ACCESS_FOR", (24 * 60 * 60).to_s).to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }
  CONFIRM_CODE_WITHIN         = env_or.call("CONFIRM_CODE_WITHIN", (10 * 60).to_s).to_i.then { |s| s.respond_to?(:seconds) ? s.seconds : s }

  # ----------------------------------------------------------------------------
  # 📦 Distributed Media & Object Storage
  # ----------------------------------------------------------------------------
  STORAGE_PROVIDER            = env_or.call("STORAGE_PROVIDER", "garage")

  # Garage S3 Self-Hosted Storage
  S3_BUCKET                   = env_or.call("S3_BUCKET", "rexone")
  S3_ENDPOINT                 = env_or.call("S3_ENDPOINT", "http://garage:3100")
  S3_PUBLIC_ENDPOINT          = env_or.call("S3_PUBLIC_ENDPOINT", "http://localhost:3100")
  S3_REGION                   = env_or.call("S3_REGION", "garage")
  S3_FOLDER_PREFIX            = env_or.call("S3_FOLDER_PREFIX", (RAILS_ENV == "development" ? "dev" : nil))
  S3_ACCESS_KEY               = env_or.call("S3_ACCESS_KEY", "")

  s3_raw_secret = env_or.call("S3_SECRET_KEY", "")
  if s3_raw_secret =~ /\A([0-9a-f]{64})/i
    S3_SECRET_KEY             = $1
  else
    S3_SECRET_KEY             = s3_raw_secret
  end

  s3_admin_ep = env_or.call("S3_ADMIN_ENDPOINT")
  if s3_admin_ep.nil? && s3_raw_secret =~ /S3_ADMIN_ENDPOINT=([^\s]+)/
    s3_admin_ep = $1
  end
  S3_ADMIN_ENDPOINT           = s3_admin_ep || "http://garage:3101"
  S3_ADMIN_TOKEN              = env_or.call("S3_ADMIN_TOKEN", nil)

  # Cloudinary Storage
  CLOUDINARY_CLOUD_NAME       = env_or.call("CLOUDINARY_CLOUD_NAME", "")
  CLOUDINARY_API_KEY          = env_or.call("CLOUDINARY_API_KEY", "")
  CLOUDINARY_API_SECRET       = env_or.call("CLOUDINARY_API_SECRET", "")

  # Local Storage
  LOCAL_STORAGE_PATH          = env_or.call("LOCAL_STORAGE_PATH", File.expand_path("../storage", __dir__))

  # Media Processing & Hardware Limits
  MEDIA_CONTAINER_ENABLED     = env_or.call("MEDIA_CONTAINER_ENABLED", "true") == "true"
  GARAGE_CONTAINER_ENABLED    = env_or.call("GARAGE_CONTAINER_ENABLED", "true") == "true"
  MEDIA_MAX_VIDEO_SIZE_MB     = env_or.call("MEDIA_MAX_VIDEO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "300" : "10").to_i
  MEDIA_MAX_AUDIO_SIZE_MB     = env_or.call("MEDIA_MAX_AUDIO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "100" : "10").to_i
  MEDIA_MAX_IMAGE_SIZE_MB     = env_or.call("MEDIA_MAX_IMAGE_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "10" : "1").to_i
  MEDIA_MAX_OTHER_SIZE_MB     = env_or.call("MEDIA_MAX_OTHER_SIZE_MB", MEDIA_CONTAINER_ENABLED ? "30" : "30").to_i
  MEDIA_VIDEO_CRF             = env_or.call("MEDIA_VIDEO_CRF", "23").to_i
  MEDIA_VIDEO_PRESET          = env_or.call("MEDIA_VIDEO_PRESET", "medium").freeze
  MEDIA_VIDEO_MAX_WIDTH       = env_or.call("MEDIA_VIDEO_MAX_WIDTH", "1920").to_i
  MEDIA_VIDEO_MAX_HEIGHT      = env_or.call("MEDIA_VIDEO_MAX_HEIGHT", "1080").to_i
  MEDIA_VIDEO_MAX_BITRATE     = env_or.call("MEDIA_VIDEO_MAX_BITRATE", "5M").freeze
  MEDIA_VIDEO_BUFFER_SIZE     = env_or.call("MEDIA_VIDEO_BUFFER_SIZE", "10M").freeze
  MEDIA_VIDEO_AUDIO_BITRATE   = env_or.call("MEDIA_VIDEO_AUDIO_BITRATE", "128k").freeze
  MEDIA_VIDEO_CODEC           = env_or.call("MEDIA_VIDEO_CODEC", "libx264").freeze
  MEDIA_VIDEO_AUDIO_CODEC     = env_or.call("MEDIA_VIDEO_AUDIO_CODEC", "aac").freeze
  MEDIA_AUDIO_BITRATE         = env_or.call("MEDIA_AUDIO_BITRATE", "128k").freeze
  MEDIA_AUDIO_CODEC           = env_or.call("MEDIA_AUDIO_CODEC", "aac").freeze
  MEDIA_IMAGE_JPEG_QUALITY    = env_or.call("MEDIA_IMAGE_JPEG_QUALITY", "82").to_i
  MEDIA_IMAGE_PNG_QUALITY     = env_or.call("MEDIA_IMAGE_PNG_QUALITY", "82").to_i
  MEDIA_IMAGE_PNG_COMPRESSION = env_or.call("MEDIA_IMAGE_PNG_COMPRESSION", "9").to_i
  MEDIA_IMAGE_WEBP_QUALITY    = env_or.call("MEDIA_IMAGE_WEBP_QUALITY", "80").to_i
  MEDIA_IMAGE_MAX_WIDTH       = env_or.call("MEDIA_IMAGE_MAX_WIDTH", "1920").to_i
  MEDIA_IMAGE_MAX_HEIGHT      = env_or.call("MEDIA_IMAGE_MAX_HEIGHT", "1080").to_i
  MEDIA_MAX_COMPRESSION_PASSES = env_or.call("MEDIA_MAX_COMPRESSION_PASSES", "2").to_i
  MEDIA_PLAYBACK_URL_TTL      = env_or.call("MEDIA_PLAYBACK_URL_TTL", "3600").to_i

  # ----------------------------------------------------------------------------
  # 💳 Payments & Stripe
  # ----------------------------------------------------------------------------
  STRIPE_SECRET_KEY           = env_or.call("STRIPE_SECRET_KEY", "")
  STRIPE_PUBLISHABLE_KEY      = env_or.call("STRIPE_PUBLISHABLE_KEY", "")
  STRIPE_WEBHOOK_SECRET       = env_or.call("STRIPE_WEBHOOK_SECRET", "")
  STRIPE_SUCCESS_URL          = env_or.call("STRIPE_SUCCESS_URL", "http://localhost:4000/success")
  STRIPE_CANCEL_URL           = env_or.call("STRIPE_CANCEL_URL", "http://localhost:4000/cancel")
  PAYMENT_BATCH_COUPON_LIMIT  = env_or.call("PAYMENT_BATCH_COUPON_LIMIT", "100").to_i

  # ----------------------------------------------------------------------------
  # 📧 Email Delivery (Brevo & SMTP)
  # ----------------------------------------------------------------------------
  EMAIL_PROVIDER              = env_or.call("EMAIL_PROVIDER", "brevo")
  FROM_EMAIL                  = env_or.call("FROM_EMAIL", "support@rexone.com")
  BREVO_API_KEY               = env_or.call("BREVO_API_KEY", "")
  BREVO_BASE_URL              = env_or.call("BREVO_BASE_URL", "https://api.brevo.com/v3")
  SMTP_ADDRESS                = env_or.call("SMTP_ADDRESS", "smtp.gmail.com")
  SMTP_PORT                   = env_or.call("SMTP_PORT", "587").to_i
  SMTP_DOMAIN                 = env_or.call("SMTP_DOMAIN", "rexone.com")
  SMTP_USERNAME               = env_or.call("SMTP_USERNAME", "")
  SMTP_PASSWORD               = env_or.call("SMTP_PASSWORD", "")

  # ----------------------------------------------------------------------------
  # 🔔 Push Notifications (OneSignal) & Retention
  # ----------------------------------------------------------------------------
  ONE_SIGNAL_APP_ID           = env_or.call("ONE_SIGNAL_APP_ID", "")
  ONE_SIGNAL_API_KEY          = env_or.call("ONE_SIGNAL_API_KEY", "")
  ONE_SIGNAL_DEFAULT_SOUND    = env_or.call("ONE_SIGNAL_DEFAULT_SOUND", "default")
  NOTIFICATION_READ_RETENTION_DAYS      = env_or.call("NOTIFICATION_READ_RETENTION_DAYS", "30").to_i
  NOTIFICATION_UNREAD_RETENTION_DAYS    = env_or.call("NOTIFICATION_UNREAD_RETENTION_DAYS", "90").to_i
  NOTIFICATION_DISCARDED_RETENTION_DAYS = env_or.call("NOTIFICATION_DISCARDED_RETENTION_DAYS", "7").to_i

  # ----------------------------------------------------------------------------
  # 🤖 AI Providers (DeepSeek & Gemini)
  # ----------------------------------------------------------------------------
  DEEPSEEK_API_KEY            = env_or.call("DEEPSEEK_API_KEY", "")
  DEEPSEEK_BASE_URL           = env_or.call("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
  DEEPSEEK_MODEL              = env_or.call("DEEPSEEK_MODEL", "deepseek-v4-flash")
  GEMINI_API_KEY              = env_or.call("GEMINI_API_KEY", "")
  GEMINI_BASE_URL             = env_or.call("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai")
  GEMINI_MODEL                = env_or.call("GEMINI_MODEL", "gemini-2.5-flash")

  # ----------------------------------------------------------------------------
  # 🎙️ Speech Services (Azure & Custom TTS/STT)
  # ----------------------------------------------------------------------------
  SPEECH_SERVICE_BASE_URL     = env_or.call("SPEECH_SERVICE_BASE_URL", "")
  SPEECH_TTS_ENDPOINT_PATH    = env_or.call("SPEECH_TTS_ENDPOINT_PATH", "/ssml-to-speech")
  SPEECH_STT_ENDPOINT_PATH    = env_or.call("SPEECH_STT_ENDPOINT_PATH", "/speech-to-text")
  AZURE_SPEECH_KEY            = env_or.call("AZURE_SPEECH_KEY", "")
  AZURE_SPEECH_REGION         = env_or.call("AZURE_SPEECH_REGION", "southeastasia")
  AZURE_SPEECH_LANGUAGE       = env_or.call("AZURE_SPEECH_LANGUAGE", "en-US")
  AZURE_SPEECH_VOICE          = env_or.call("AZURE_SPEECH_VOICE", "en-US-AvaNeural")

  # ----------------------------------------------------------------------------
  # 📊 Telemetry, Client Stores & Observability
  # ----------------------------------------------------------------------------
  DASHBOARD_BASE_URL          = env_or.call("DASHBOARD_BASE_URL", nil)
  APP_VERSION                 = env_or.call("APP_VERSION", nil)
  GIT_SHA                     = env_or.call("GIT_SHA", nil)
  IOS_STORE_URL               = env_or.call("IOS_STORE_URL", nil)
  ANDROID_STORE_URL           = env_or.call("ANDROID_STORE_URL", nil)
  # ----------------------------------------------------------------------------
  # 🛡️ Diagnostics & Boot Guard
  # ----------------------------------------------------------------------------
  ENFORCE_BOOT_GUARD          = env_or.call("ENFORCE_BOOT_GUARD") == "true"
  TEST_BOOT_GUARD             = env_or.call("TEST_BOOT_GUARD") == "true"
  QUIET_BOOT                  = env_or.call("QUIET_BOOT") == "true"

  # ----------------------------------------------------------------------------
  # 🔗 URL Construction Helpers
  # ----------------------------------------------------------------------------
  class << self
    def client_url(path = nil)
      base = CLIENT_BASE_URL.to_s.chomp("/")
      return base if path.blank?

      p = path.to_s.strip
      return p if p.start_with?("http://", "https://", "mailto:", "tel:", "rexone://")

      p = "/#{p}" unless p.start_with?("/")
      "#{base}#{p}"
    end

    def server_url(path = nil)
      base = SERVER_BASE_URL.to_s.chomp("/")
      return base if path.blank?

      p = path.to_s.strip
      return p if p.start_with?("http://", "https://", "mailto:", "tel:")

      p = "/#{p}" unless p.start_with?("/")
      "#{base}#{p}"
    end
  end
end
