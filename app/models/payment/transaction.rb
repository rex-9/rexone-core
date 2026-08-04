# app/models/payment/transaction.rb
# Stripe has Transaction Object... we better use it???
# https://docs.stripe.com/api/issuing/transactions/object

class Payment::Transaction < ApplicationRecord
  self.table_name = "payment_transactions"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product", optional: true, inverse_of: :transactions

  # ===== ENUMS =====
  enum :status, {
    pending: "pending",    # Started but not completed
    paid: "paid",          # Payment successful
    failed: "failed",      # Payment failed
    refunded: "refunded",  # Refunded
    disputed: "disputed"   # Chargeback/dispute
  }

  enum :payment_method_type, {
    card: "card",
    google_pay: "google_pay",
    apple_pay: "apple_pay",
    bank_transfer: "bank_transfer",
    other: "other"
  }, prefix: true

  # ===== VALIDATIONS =====
  validates :stripe_payment_intent, presence: true, uniqueness: true
  validates :price_unit_amount, numericality: { greater_than: 0 }

  # ===== SCOPES =====
  scope :successful, -> { where(status: "paid") }
  scope :refunded, -> { where(status: "refunded") }
  scope :recent, -> { order(created_at: :desc).limit(10) }

  # ===== INSTANCE METHODS =====
  def paid?
    status == "paid"
  end

  def refunded?
    status == "refunded"
  end

  def mark_as_paid!
    update(status: "paid", paid_at: Time.current)
  end

  def mark_as_refunded!
    update(status: "refunded", refunded_at: Time.current)
  end

  def display_price
    format("%s %.2f", currency.upcase, price_unit_amount / 100.0)
  end

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
