# frozen_string_literal: true

# app/models/payment/purchase.rb
# Synced with Stripe Payment Intent Object
# https://docs.stripe.com/api/payment_intents/object

class Payment::Purchase < ApplicationRecord
  self.table_name = "payment_purchases"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product", optional: true, inverse_of: :purchases
  has_one :user_coupon, -> { where(payment_type: :purchase) },
          class_name: "Payment::UserCoupon",
          foreign_key: :payment_id,
          dependent: :nullify,
          inverse_of: false
  has_one :coupon, through: :user_coupon, class_name: "Payment::Coupon"

  # ===== ENUMS =====
  # Stripe Payment Intent statuses (sync with Stripe)
  enum :status, {
    canceled: PaymentConstants::PurchaseStatus::CANCELED,
    processing: PaymentConstants::PurchaseStatus::PROCESSING,
    requires_action: PaymentConstants::PurchaseStatus::REQUIRES_ACTION,
    requires_capture: PaymentConstants::PurchaseStatus::REQUIRES_CAPTURE,
    requires_confirmation: PaymentConstants::PurchaseStatus::REQUIRES_CONFIRMATION,
    requires_payment_method: PaymentConstants::PurchaseStatus::REQUIRES_PAYMENT_METHOD,
    succeeded: PaymentConstants::PurchaseStatus::SUCCEEDED
  }

  # ===== VALIDATIONS =====
  validates :provider, presence: true, inclusion: { in: PaymentConstants::Provider::ALL }
  validates :provider_payment_id, presence: true, uniqueness: true
  validates :unit_amount, numericality: { greater_than_or_equal_to: 0 }

  # ===== SCOPES =====
  scope :successful, -> { where(status: PaymentConstants::PurchaseStatus::SUCCEEDED) }
  scope :pending, -> { where(status: [ PaymentConstants::PurchaseStatus::PROCESSING, PaymentConstants::PurchaseStatus::REQUIRES_ACTION, PaymentConstants::PurchaseStatus::REQUIRES_CONFIRMATION, PaymentConstants::PurchaseStatus::REQUIRES_PAYMENT_METHOD ]) }
  scope :failed, -> { where(status: [ PaymentConstants::PurchaseStatus::CANCELED ]) }
  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :for_provider, ->(provider_name) { where(provider: provider_name) }

  # ===== INSTANCE METHODS =====
  def succeeded?
    status == PaymentConstants::PurchaseStatus::SUCCEEDED
  end

  def paid?
    succeeded?
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

  def stripe?
    provider == PaymentConstants::Provider::STRIPE
  end

  def google_play?
    provider == PaymentConstants::Provider::GOOGLE_PLAY
  end

  def app_store?
    provider == PaymentConstants::Provider::APP_STORE
  end

  def in_app?
    google_play? || app_store?
  end

  # Update status from Stripe Payment Intent
  def sync_with_payment_intent(payment_intent)
    assign_attributes(
      status: payment_intent.status,
      unit_amount: payment_intent.amount,
      currency: payment_intent.currency,
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
    update!(
      status: "succeeded",
      paid_at: Time.current
    )
  end

  # Mark as processing (webhook: payment_intent.processing)
  def mark_as_processing!
    update!(
      status: "processing",
      processing_at: Time.current
    )
  end

  # Mark as canceled (webhook: payment_intent.canceled)
  def mark_as_canceled!
    update!(
      status: "canceled",
      canceled_at: Time.current
    )
  end

  # Display price with currency
  def display_price
    format("%s %.2f", currency.upcase, unit_amount / 100.0)
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
