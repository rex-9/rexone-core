# app/serializers/payment/transaction_serializer.rb
class Payment::TransactionSerializer < ApplicationSerializer
  attributes :id, :stripe_payment_intent_id, :stripe_charge_id, :stripe_customer_id,
             :status, :payment_method_id, :payment_method_type,
             :unit_amount, :currency, :client_secret,
             :paid_at, :refunded_at, :canceled_at, :processing_at,
             :amount_received, :amount_capturable,
             :created_at, :updated_at, :user_id, :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer, optional: true

  # Formatted price
  attribute :price do |transaction|
    transaction.display_price
  end

  # Status helpers
  attribute :paid do |transaction|
    transaction.paid?
  end

  attribute :pending do |transaction|
    transaction.pending?
  end

  attribute :failed do |transaction|
    transaction.failed?
  end

  attribute :requires_action do |transaction|
    transaction.requires_action?
  end

  # Payment method display
  attribute :payment_method_display do |transaction|
    transaction.payment_method_display
  end

  attribute :card_last4 do |transaction|
    transaction.card_last4
  end

  attribute :card_brand do |transaction|
    transaction.card_brand
  end

  attribute :masked_card_number do |transaction|
    transaction.masked_card_number
  end

  # Product details
  attribute :product_name do |transaction|
    transaction.product&.name
  end

  attribute :product_code do |transaction|
    transaction.product&.code
  end

  attribute :user_name do |transaction|
    transaction.user&.name
  end

  attribute :username do |transaction|
    transaction.user&.username
  end

  attribute :user_email do |transaction|
    transaction.user&.email
  end

  attribute :coupon do |transaction|
    user_coupon = transaction.user_coupon
    if user_coupon.present?
      coupon = user_coupon.coupon
      {
        id: coupon&.id,
        code: coupon&.code,
        title: coupon&.title,
        coupon_type: coupon&.coupon_type,
        discount_amount: user_coupon.discount_amount,
        original_amount: user_coupon.original_amount,
        final_amount: user_coupon.final_amount,
        currency: user_coupon.currency
      }
    end
  end
end
