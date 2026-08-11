# app/models/payment/transaction.rb
# Synced with Stripe Payment Intent Object
# https://docs.stripe.com/api/payment_intents/object

class Payment::Transaction < ApplicationRecord
  self.table_name = "payment_transactions"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product", optional: true, inverse_of: :transactions

  # ===== ENUMS =====
  # Stripe Payment Intent statuses (sync with Stripe)
  enum :status, {
    canceled: "canceled",                               # Canceled by user or system
    processing: "processing",                           # Currently being processed
    requires_action: "requires_action",                 # Requires additional action (3DS)
    requires_capture: "requires_capture",               # Confirmed and requires capture
    requires_confirmation: "requires_confirmation",     # Requires confirmation
    requires_payment_method: "requires_payment_method", # Requires a payment method
    succeeded: "succeeded"                              # Payment successful
  }

  enum :payment_method_type, {
    card: "card",
    google_pay: "google_pay",
    apple_pay: "apple_pay",
    bank_transfer: "bank_transfer",
    other: "other"
  }, prefix: true

  # ===== VALIDATIONS =====
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  validates :price_unit_amount, numericality: { greater_than: 0 }

  # ===== SCOPES =====
  scope :successful, -> { where(status: "succeeded") }
  scope :pending, -> { where(status: %w[processing requires_action requires_confirmation requires_payment_method]) }
  scope :failed, -> { where(status: %w[canceled]) }
  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # ===== INSTANCE METHODS =====
  def succeeded?
    status == "succeeded"
  end

  def paid?
    succeeded?
  end

  def refunded?
    status == "refunded"
  end

  def pending?
    %w[processing requires_action requires_confirmation requires_payment_method].include?(status)
  end

  def failed?
    status == "canceled"
  end

  def requires_action?
    status == "requires_action"
  end

  # Update status from Stripe Payment Intent
  def sync_with_payment_intent(payment_intent)
    assign_attributes(
      status: payment_intent.status,
      amount_received: payment_intent.amount_received,
      amount_capturable: payment_intent.amount_capturable,
      client_secret: payment_intent.client_secret,
      metadata: payment_intent.metadata,
      paid_at: payment_intent.amount_received > 0 ? Time.current : nil
    )

    save! if changed?
  end

  # Mark as paid (webhook: payment_intent.succeeded)
  def mark_as_succeeded!
    update(
      status: "succeeded",
      paid_at: Time.current
    )
  end

  # Mark as processing (webhook: payment_intent.processing)
  def mark_as_processing!
    update(
      status: "processing",
      processing_at: Time.current
    )
  end

  # Mark as canceled (webhook: payment_intent.canceled)
  def mark_as_canceled!
    update(
      status: "canceled",
      canceled_at: Time.current
    )
  end

  # Display price with currency
  def display_price
    format("%s %.2f", currency.upcase, price_unit_amount / 100.0)
  end

  # Payment method display
  def card_last4
    payment_method_details&.dig("last4")
  end

  def card_brand
    payment_method_details&.dig("brand") || payment_method_type || "card"
  end

  def masked_card_number
    "**** **** **** #{card_last4}" if card_last4.present?
  end

  def payment_method_display
    return "Unknown" if payment_method_id.blank?

    brand = card_brand&.capitalize || payment_method_type&.capitalize || "Other"
    card_last4.present? ? "#{brand} ending in #{card_last4}" : brand
  end
end
