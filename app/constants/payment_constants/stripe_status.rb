# app/constants/payment_constants/stripe_status.rb

module PaymentConstants
  module StripeStatus
    PAID       = "paid".freeze
    PAST_DUE   = "past_due".freeze
    CANCELED   = "canceled".freeze
    REFUNDED   = "refunded".freeze
    OTHER      = "other".freeze
  end
end
