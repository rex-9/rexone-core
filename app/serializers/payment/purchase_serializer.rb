# frozen_string_literal: true

# app/serializers/payment/purchase_serializer.rb
class Payment::PurchaseSerializer < ApplicationSerializer
  attributes :id, :provider, :provider_payment_id, :provider_charge_id, :provider_customer_id,
             :status, :payment_method_id, :payment_method_type,
             :unit_amount, :currency, :client_secret,
             :paid_at, :refunded_at, :canceled_at, :processing_at,
             :amount_received, :amount_capturable,
             :created_at, :updated_at, :user_id, :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer, optional: true

  # Formatted price
  attribute :price do |purchase|
    purchase.display_price
  end

  # Status helpers
  attribute :paid do |purchase|
    purchase.paid?
  end

  attribute :pending do |purchase|
    purchase.pending?
  end

  attribute :failed do |purchase|
    purchase.failed?
  end

  attribute :requires_action do |purchase|
    purchase.requires_action?
  end

  # Payment method display
  attribute :payment_method_display do |purchase|
    purchase.payment_method_display
  end

  attribute :card_last4 do |purchase|
    purchase.card_last4
  end

  attribute :card_brand do |purchase|
    purchase.card_brand
  end

  attribute :masked_card_number do |purchase|
    purchase.masked_card_number
  end

  # Product details
  attribute :product_name do |purchase|
    purchase.product&.name
  end

  attribute :product_code do |purchase|
    purchase.product&.code
  end

  attribute :user_name do |purchase|
    purchase.user&.name
  end

  attribute :username do |purchase|
    purchase.user&.username
  end

  attribute :user_email do |purchase|
    purchase.user&.email
  end

  attribute :coupon do |purchase|
    Payment::UserCouponSerializer.record_attributes(purchase.user_coupon)
  end
end
