# frozen_string_literal: true

# app/constants/payment_constants.rb
module PaymentConstants
  module Provider
    STRIPE      = "stripe".freeze
    GOOGLE_PLAY = "google_play".freeze
    APP_STORE   = "app_store".freeze
    IN_APP      = [ GOOGLE_PLAY, APP_STORE ].freeze
    ALL         = [ STRIPE, GOOGLE_PLAY, APP_STORE ].freeze
  end

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

  module PurchaseStatus
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
    SUBSCRIPTION_CREATED       = "customer.subscription.created".freeze
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
      SUBSCRIPTION_CREATED,
      SUBSCRIPTION_UPDATED, SUBSCRIPTION_DELETED,
      SUBSCRIPTION_PAUSED, SUBSCRIPTION_RESUMED,
      PRODUCT_UPDATED,
      PRICE_CREATED, PRICE_UPDATED, PRICE_DELETED,
      COUPON_CREATED, COUPON_UPDATED, COUPON_DELETED
    ].freeze
  end

  module AppStoreNotificationType
    SUBSCRIBED                = "SUBSCRIBED".freeze
    DID_CHANGE_RENEWAL_PREF   = "DID_CHANGE_RENEWAL_PREF".freeze
    DID_CHANGE_RENEWAL_STATUS = "DID_CHANGE_RENEWAL_STATUS".freeze
    OFFER_REDEEMED            = "OFFER_REDEEMED".freeze
    DID_RENEW                 = "DID_RENEW".freeze
    EXPIRED                   = "EXPIRED".freeze
    DID_FAIL_TO_RENEW         = "DID_FAIL_TO_RENEW".freeze
    GRACE_PERIOD_EXPIRED      = "GRACE_PERIOD_EXPIRED".freeze
    PRICE_INCREASE            = "PRICE_INCREASE".freeze
    REFUND                    = "REFUND".freeze
    REFUND_DECLINED           = "REFUND_DECLINED".freeze
    CONSUMPTION_REQUEST       = "CONSUMPTION_REQUEST".freeze
    RENEWAL_EXTENDED          = "RENEWAL_EXTENDED".freeze
    REVOKE                    = "REVOKE".freeze
    TEST                      = "TEST".freeze

    ALL = [
      SUBSCRIBED,
      DID_CHANGE_RENEWAL_PREF,
      DID_CHANGE_RENEWAL_STATUS,
      OFFER_REDEEMED,
      DID_RENEW,
      EXPIRED,
      DID_FAIL_TO_RENEW,
      GRACE_PERIOD_EXPIRED,
      PRICE_INCREASE,
      REFUND,
      REFUND_DECLINED,
      CONSUMPTION_REQUEST,
      RENEWAL_EXTENDED,
      REVOKE,
      TEST
    ].freeze
  end
  AppStoreEvent = AppStoreNotificationType

  module GooglePlayNotificationType
    SUBSCRIPTION_RECOVERED              = "SUBSCRIPTION_RECOVERED".freeze
    SUBSCRIPTION_RENEWED                = "SUBSCRIPTION_RENEWED".freeze
    SUBSCRIPTION_CANCELED               = "SUBSCRIPTION_CANCELED".freeze
    SUBSCRIPTION_PURCHASED              = "SUBSCRIPTION_PURCHASED".freeze
    SUBSCRIPTION_ON_HOLD                = "SUBSCRIPTION_ON_HOLD".freeze
    SUBSCRIPTION_IN_GRACE_PERIOD        = "SUBSCRIPTION_IN_GRACE_PERIOD".freeze
    SUBSCRIPTION_RESTARTED              = "SUBSCRIPTION_RESTARTED".freeze
    SUBSCRIPTION_PRICE_CHANGE_CONFIRMED = "SUBSCRIPTION_PRICE_CHANGE_CONFIRMED".freeze
    SUBSCRIPTION_DEFERRED               = "SUBSCRIPTION_DEFERRED".freeze
    SUBSCRIPTION_PAUSED                 = "SUBSCRIPTION_PAUSED".freeze
    SUBSCRIPTION_REVOKED                = "SUBSCRIPTION_REVOKED".freeze
    SUBSCRIPTION_EXPIRED                = "SUBSCRIPTION_EXPIRED".freeze
    ONE_TIME_PRODUCT_PURCHASED          = "ONE_TIME_PRODUCT_PURCHASED".freeze
    ONE_TIME_PRODUCT_CANCELED           = "ONE_TIME_PRODUCT_CANCELED".freeze

    ALL = [
      SUBSCRIPTION_RECOVERED,
      SUBSCRIPTION_RENEWED,
      SUBSCRIPTION_CANCELED,
      SUBSCRIPTION_PURCHASED,
      SUBSCRIPTION_ON_HOLD,
      SUBSCRIPTION_IN_GRACE_PERIOD,
      SUBSCRIPTION_RESTARTED,
      SUBSCRIPTION_PRICE_CHANGE_CONFIRMED,
      SUBSCRIPTION_DEFERRED,
      SUBSCRIPTION_PAUSED,
      SUBSCRIPTION_REVOKED,
      SUBSCRIPTION_EXPIRED,
      ONE_TIME_PRODUCT_PURCHASED,
      ONE_TIME_PRODUCT_CANCELED
    ].freeze
  end
  GooglePlayEvent = GooglePlayNotificationType

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

  module PaymentType
    PURCHASE     = "purchase".freeze
    SUBSCRIPTION = "subscription".freeze
    ALL          = [ PURCHASE, SUBSCRIPTION ].freeze
    INTEGER_MAPPING = {
      purchase: 0,
      subscription: 1
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
