# app/constants/payment_constants.rb

module PaymentConstants
  module SubscriptionStatus
    INCOMPLETE         = "incomplete".freeze
    ACTIVE             = "active".freeze
    PAST_DUE           = "past_due".freeze
    CANCELED           = "canceled".freeze
    INCOMPLETE_EXPIRED = "incomplete_expired".freeze
    UNPAID             = "unpaid".freeze
    TRIALING           = "trialing".freeze
    PAUSED             = "paused".freeze
    ALL                = [
      INCOMPLETE, ACTIVE, PAST_DUE, CANCELED,
      INCOMPLETE_EXPIRED, UNPAID, TRIALING, PAUSED
    ].freeze
  end

  module BillingCycle
    MONTH = "month".freeze
    YEAR  = "year".freeze
    ALL   = [ MONTH, YEAR ].freeze
  end

  module PaymentMethodType
    CARD          = "card".freeze
    GOOGLE_PAY    = "google_pay".freeze
    APPLE_PAY     = "apple_pay".freeze
    BANK_TRANSFER = "bank_transfer".freeze
    OTHER         = "other".freeze
    ALL           = [ CARD, GOOGLE_PAY, APPLE_PAY, BANK_TRANSFER, OTHER ].freeze
  end

  module TransactionStatus
    SUCCEEDED               = "succeeded".freeze
    PROCESSING              = "processing".freeze
    REQUIRES_ACTION         = "requires_action".freeze
    REQUIRES_CAPTURE        = "requires_capture".freeze
    REQUIRES_CONFIRMATION   = "requires_confirmation".freeze
    REQUIRES_PAYMENT_METHOD = "requires_payment_method".freeze
    CANCELED                = "canceled".freeze
    ALL                     = [
      SUCCEEDED, PROCESSING, REQUIRES_ACTION, REQUIRES_CAPTURE,
      REQUIRES_CONFIRMATION, REQUIRES_PAYMENT_METHOD, CANCELED
    ].freeze
  end

  module WebhookStatus
    PENDING    = "pending".freeze
    PROCESSING = "processing".freeze
    PROCESSED  = "processed".freeze
    FAILED     = "failed".freeze
    ALL        = [ PENDING, PROCESSING, PROCESSED, FAILED ].freeze
  end
end
