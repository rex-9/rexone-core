# frozen_string_literal: true

# app/constants/payment_constants.rb
module PaymentConstants
  module StripeApi
    VERSION = "2026-08-26.dahlia".freeze
  end

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

  module BillingInterval
    DAY   = "day".freeze
    WEEK  = "week".freeze
    MONTH = "month".freeze
    YEAR  = "year".freeze
    ALL   = [ DAY, WEEK, MONTH, YEAR ].freeze
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

  module StripeEvent
    CHECKOUT_SESSION_COMPLETED = "checkout.session.completed".freeze
    SUBSCRIPTION_UPDATED       = "customer.subscription.updated".freeze
    SUBSCRIPTION_DELETED       = "customer.subscription.deleted".freeze
    SUBSCRIPTION_PAUSED        = "customer.subscription.paused".freeze
    SUBSCRIPTION_RESUMED       = "customer.subscription.resumed".freeze
    PRODUCT_UPDATED            = "product.updated".freeze
    PRICE_CREATED              = "price.created".freeze
    PRICE_UPDATED              = "price.updated".freeze
    PRICE_DELETED              = "price.deleted".freeze

    COUPON_CREATED             = "coupon.created".freeze
    COUPON_UPDATED             = "coupon.updated".freeze
    COUPON_DELETED             = "coupon.deleted".freeze

    ALL = [
      CHECKOUT_SESSION_COMPLETED,
      SUBSCRIPTION_UPDATED, SUBSCRIPTION_DELETED,
      SUBSCRIPTION_PAUSED, SUBSCRIPTION_RESUMED,
      PRODUCT_UPDATED,
      PRICE_CREATED, PRICE_UPDATED, PRICE_DELETED,
      COUPON_CREATED, COUPON_UPDATED, COUPON_DELETED
    ].freeze
  end

  module StripeMode
    SUBSCRIPTION = "subscription".freeze
    PAYMENT      = "payment".freeze
  end

  module StripeStatus
    PAID       = "paid".freeze
    PAST_DUE   = "past_due".freeze
    CANCELED   = "canceled".freeze
    REFUNDED   = "refunded".freeze
    OTHER      = "other".freeze
  end

  module CouponType
    PERCENTAGE = "percentage".freeze
    FIXED      = "fixed".freeze
    ALL        = [ PERCENTAGE, FIXED ].freeze
    INTEGER_MAPPING = {
      percentage: 0,
      fixed: 1
    }.freeze
  end

  module PurchaseType
    TRX = "trx".freeze
    SBS = "sbs".freeze
    ALL = [ TRX, SBS ].freeze
    INTEGER_MAPPING = {
      trx: 0,
      sbs: 1
    }.freeze
  end

  module Currency
    USD = "usd".freeze
    MMK = "mmk".freeze
    SGD = "sgd".freeze
    ALL = [ USD, MMK, SGD ].freeze
  end

  module SyncStatus
    PENDING    = "pending".freeze
    PROCESSING = "processing".freeze
    SUCCEEDED  = "succeeded".freeze
    FAILED     = "failed".freeze
    ALL        = [ PENDING, PROCESSING, SUCCEEDED, FAILED ].freeze
  end

  module Batch
    MAX_COUPONS = 100
  end

  # Official Stripe minimum charge amounts in minor currency units
  # Reference: https://docs.stripe.com/currencies#minimum-and-maximum-charge-amounts
  module StripeMinimumAmount
    LIMITS = {
      "usd" => 50,    # $0.50 USD
      "sgd" => 50,    # $0.50 SGD
      "eur" => 50,    # €0.50 EUR
      "gbp" => 30,    # £0.30 GBP
      "aud" => 50,    # $0.50 AUD
      "cad" => 50,    # $0.50 CAD
      "chf" => 50,    # 0.50 CHF
      "jpy" => 50,    # ¥50 JPY
      "hkd" => 400,   # $4.00 HKD
      "myr" => 200,   # 2.00 MYR
      "thb" => 1000,  # 10.00 THB
      "nzd" => 50,    # $0.50 NZD
      "sek" => 300,   # 3.00 SEK
      "nok" => 300,   # 3.00 NOK
      "dkk" => 250,   # 2.50 DKK
      "pln" => 200,   # 2.00 PLN
      "inr" => 50,    # ₹0.50 INR
      "brl" => 50,    # R$0.50 BRL
      "mxn" => 1000,  # $10.00 MXN
      "aed" => 200,   # 2.00 AED
      "czk" => 1500,  # 15.00 CZK
      "huf" => 17500, # 175.00 HUF
      "ron" => 200,   # 2.00 RON
      "bgn" => 100,   # 1.00 BGN
      "mmk" => 50     # Fallback
    }.freeze

    DEFAULT = 50

    def self.for(currency)
      LIMITS.fetch(currency.to_s.downcase, DEFAULT)
    end
  end
end
