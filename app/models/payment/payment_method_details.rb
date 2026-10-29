# frozen_string_literal: true

# app/models/payment/payment_method_details.rb
# Deterministic typed contract for card, Google Play, and Apple App Store payment method snapshots.
module Payment
  class PaymentMethodDetails < ApplicationMetadata
    attribute :brand, :string
    attribute :last4, :string
    attribute :exp_month, :integer
    attribute :exp_year, :integer
    attribute :country, :string
    attribute :type, :string
    attribute :funding, :string
    attribute :order_id, :string
    attribute :purchase_token, :string
    attribute :package_name, :string
    attribute :transaction_id, :string
    attribute :original_transaction_id, :string
    attribute :bundle_id, :string

    validates :exp_month, numericality: { only_integer: true, in: 1..12 }, allow_nil: true
    validates :exp_year, numericality: { only_integer: true, greater_than_or_equal_to: 2000 }, allow_nil: true
  end
end
