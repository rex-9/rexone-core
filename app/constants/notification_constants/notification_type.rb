# app/constants/notification_constants/notification_type.rb

module NotificationConstants
  module NotificationType
    PAYMENT_SUCCESS       = "payment_success".freeze
    PAYMENT_FAILED        = "payment_failed".freeze
    SUBSCRIPTION_CREATED  = "subscription_created".freeze
    SUBSCRIPTION_CANCELED = "subscription_canceled".freeze
    SUBSCRIPTION_RESUMED  = "subscription_resumed".freeze
    AI_RESPONSE_READY     = "ai_response_ready".freeze
    AI_RESPONSE_FAILED    = "ai_response_failed".freeze
    TTS_READY             = "tts_ready".freeze
    TTS_FAILED            = "tts_failed".freeze
    WELCOME               = "welcome".freeze
    SIGN_IN_ALERT         = "sign_in_alert".freeze
    NOTIFICATION          = "notification".freeze
  end
end
