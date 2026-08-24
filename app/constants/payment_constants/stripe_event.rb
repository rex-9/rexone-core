# app/constants/payment_constants/stripe_event.rb

module PaymentConstants
  module StripeEvent
    CHECKOUT_SESSION_COMPLETED = "checkout.session.completed".freeze
    SUBSCRIPTION_UPDATED       = "customer.subscription.updated".freeze
    SUBSCRIPTION_DELETED       = "customer.subscription.deleted".freeze
    SUBSCRIPTION_PAUSED        = "customer.subscription.paused".freeze
    SUBSCRIPTION_RESUMED       = "customer.subscription.resumed".freeze
    PRODUCT_CREATED            = "product.created".freeze
    PRODUCT_UPDATED            = "product.updated".freeze
    PRODUCT_DELETED            = "product.deleted".freeze
    PRICE_CREATED              = "price.created".freeze
    PRICE_UPDATED              = "price.updated".freeze
    PRICE_DELETED              = "price.deleted".freeze

    ALL = [
      CHECKOUT_SESSION_COMPLETED,
      SUBSCRIPTION_UPDATED, SUBSCRIPTION_DELETED,
      SUBSCRIPTION_PAUSED, SUBSCRIPTION_RESUMED,
      PRODUCT_CREATED, PRODUCT_UPDATED, PRODUCT_DELETED,
      PRICE_CREATED, PRICE_UPDATED, PRICE_DELETED
    ].freeze
  end
end
