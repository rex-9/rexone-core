# frozen_string_literal: true

# app/constants/notification_constants.rb
module NotificationConstants
  module Event
    FORMAT = /\A[a-z][a-z0-9_]*\z/.freeze
  end

  module Client
    WEB = "web".freeze
    MOBILE = "mobile".freeze
    DEFAULT = [ WEB, MOBILE ].freeze
    ADMIN_PORTAL = [ WEB ].freeze
    FORMAT = /\A[a-z][a-z0-9_]*\z/.freeze
  end

  module Link
    HOME = "/home".freeze
    PROFILE = "/profile".freeze
    PAYMENT = "/payment".freeze
    AI = "/ai".freeze
    HTTPS_PREFIX = "https://".freeze

    TEMPLATE_LINKS = [ HOME, PROFILE, PAYMENT, AI ].freeze
  end

  module OperationStatus
    QUEUED = "queued".freeze
    PROCESSING = "processing".freeze
    COMPLETED = "completed".freeze
    FAILED = "failed".freeze
    ALL = [ QUEUED, PROCESSING, COMPLETED, FAILED ].freeze
  end

  module OperationType
    AI_RESPONSE = "ai_response".freeze
    ASSET_COMPRESSION = "asset_compression".freeze
    VIDEO_THUMBNAIL = "video_thumbnail".freeze
    NOTIFICATION_DELIVERY = "notification_delivery".freeze
    PAYMENT_WEBHOOK = "payment_webhook".freeze
    ALL = [ AI_RESPONSE, ASSET_COMPRESSION, VIDEO_THUMBNAIL, NOTIFICATION_DELIVERY, PAYMENT_WEBHOOK ].freeze
  end

  module AudienceType
    ALL       = "all".freeze
    ROLES     = "roles".freeze
    USERS     = "users".freeze
    AUDIENCES = [ ALL, ROLES, USERS ].freeze
  end

  module Category
    SYSTEM    = "system".freeze
    MARKETING = "marketing".freeze
    BROADCAST = "broadcast".freeze

    ALL = [
      SYSTEM,
      MARKETING,
      BROADCAST
    ].freeze
  end

  module Channel
    SOCKET   = "socket".freeze
    PUSH     = "push".freeze
    EMAIL    = "email".freeze
    CHANNELS = [ SOCKET, PUSH, EMAIL ].freeze
    ALL      = CHANNELS
  end

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
    IAM_UPDATED           = "iam_updated".freeze
    NOTIFICATION          = "notification".freeze
  end

  module DefaultNotifications
    ALL = [
      {
        event: NotificationType::WELCOME,
        name: "Welcome to RexOne",
        description: "Sent when a new user joins the platform",
        category: Category::SYSTEM,
        link: Link::HOME,
        admin: true,
        in_app_title: "Welcome aboard! 🎉",
        in_app_body: "Hey {{user_name}}, thanks for joining RexOne! We're excited to have you.",
        push_title: "Welcome aboard! 🎉",
        push_body: "Hey {{user_name}}, thanks for joining RexOne!",
        email_subject: "Welcome to RexOne!",
        email_body: "Welcome to RexOne, {{user_name}}!",
        email_template_id: "welcome"
      }.freeze,
      {
        event: NotificationType::SIGN_IN_ALERT,
        name: "New Sign In Alert",
        description: "Sent when a new sign-in is detected",
        category: Category::SYSTEM,
        link: Link::PROFILE,
        admin: true,
        in_app_title: "New Sign In",
        in_app_body: "Hi {{user_name}}, we noticed a new sign-in to your account at {{time}}.",
        push_title: "New Sign In",
        push_body: "Hi {{user_name}}, new sign-in detected.",
        email_subject: "Security Alert: New Sign In",
        email_body: "Hi {{user_name}}, we noticed a new sign-in to your account.",
        email_template_id: "sign_in_alert"
      }.freeze,
      {
        event: NotificationType::PAYMENT_SUCCESS,
        name: "Payment Success",
        description: "Sent upon successful payment processing",
        category: Category::SYSTEM,
        link: Link::PAYMENT,
        admin: true,
        in_app_title: "Payment Successful",
        in_app_body: "Your payment of {{amount}} for {{product_name}} was completed successfully.",
        push_title: "Payment Successful",
        push_body: "Payment of {{amount}} received for {{product_name}}.",
        email_subject: "Payment Confirmation - {{product_name}}",
        email_template_id: "payment_purchase_confirmation"
      }.freeze,
      {
        event: NotificationType::PAYMENT_FAILED,
        name: "Payment Failed",
        description: "Sent when an invoice payment fails",
        category: Category::SYSTEM,
        link: Link::PAYMENT,
        admin: true,
        in_app_title: "Payment Failed",
        in_app_body: "Your payment of {{amount}} for {{product_name}} could not be processed.",
        push_title: "Payment Failed",
        push_body: "Payment failed for {{product_name}}.",
        email_subject: "Payment Failed - Action Required",
        email_template_id: "payment_failed"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_CREATED,
        name: "Subscription Started",
        description: "Sent when a new subscription is activated",
        category: Category::SYSTEM,
        link: Link::PAYMENT,
        admin: true,
        in_app_title: "Subscription Started",
        in_app_body: "You are now subscribed to {{product_name}} ({{period}}).",
        push_title: "Subscription Started",
        push_body: "You are subscribed to {{product_name}}.",
        email_subject: "Subscription Confirmation - {{product_name}}",
        email_template_id: "payment_subscription_confirmation"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_CANCELED,
        name: "Subscription Canceled",
        description: "Sent when a subscription cancellation is scheduled",
        category: Category::SYSTEM,
        link: Link::PAYMENT,
        admin: true,
        in_app_title: "Subscription Canceled",
        in_app_body: "Your subscription to {{product_name}} has been canceled. Access remains active until {{active_until}}.",
        push_title: "Subscription Canceled",
        push_body: "Subscription to {{product_name}} canceled.",
        email_subject: "Subscription Canceled",
        email_template_id: "payment_subscription_canceled"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_RESUMED,
        name: "Subscription Resumed",
        description: "Sent when a pending canceled subscription is resumed",
        category: Category::SYSTEM,
        link: Link::PAYMENT,
        admin: true,
        in_app_title: "Subscription Resumed",
        in_app_body: "Your subscription to {{product_name}} has been successfully resumed.",
        push_title: "Subscription Resumed",
        push_body: "Subscription to {{product_name}} resumed.",
        email_subject: "Subscription Resumed",
        email_template_id: "payment_subscription_resumed"
      }.freeze
    ].freeze
  end
end
