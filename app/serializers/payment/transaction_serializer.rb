# app/serializers/payment/transaction_serializer.rb
class Payment::TransactionSerializer < ApplicationSerializer
  attributes :id, :stripe_payment_intent_id, :stripe_charge_id, :stripe_customer_id,
             :status, :payment_method_id, :payment_method_type,
             :price_unit_amount, :currency, :client_secret,
             :paid_at, :refunded_at, :canceled_at, :processing_at,
             :amount_received, :amount_capturable,
             :created_at, :updated_at, :user_id, :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer, optional: true

  # Formatted price
  attribute :price_unit_amount do |transaction|
    transaction.display_price
  end

  # Status helpers
  attribute :paid do |transaction|
    transaction.paid?
  end

  attribute :refunded do |transaction|
    transaction.refunded?
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
end
