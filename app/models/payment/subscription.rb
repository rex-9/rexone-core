# app/models/payment/subscription.rb
# Synced with Stripe Subscription Object
# https://docs.stripe.com/api/subscriptions/object
class Payment::Subscription < ApplicationRecord
  self.table_name = "payment_subscriptions"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product", inverse_of: :subscriptions

  # ===== ENUMS =====
  enum :status, {
    incomplete: PaymentConstants::SubscriptionStatus::INCOMPLETE,
    active: PaymentConstants::SubscriptionStatus::ACTIVE,
    past_due: PaymentConstants::SubscriptionStatus::PAST_DUE,
    canceled: PaymentConstants::SubscriptionStatus::CANCELED,
    incomplete_expired: PaymentConstants::SubscriptionStatus::INCOMPLETE_EXPIRED,
    unpaid: PaymentConstants::SubscriptionStatus::UNPAID,
    trialing: PaymentConstants::SubscriptionStatus::TRIALING,
    paused: PaymentConstants::SubscriptionStatus::PAUSED
  }

  enum :cycle, {
    monthly: PaymentConstants::BillingCycle::MONTH,
    yearly: PaymentConstants::BillingCycle::YEAR
  }, prefix: true

  enum :payment_method_type, {
    card: PaymentConstants::PaymentMethodType::CARD,
    google_pay: PaymentConstants::PaymentMethodType::GOOGLE_PAY,
    apple_pay: PaymentConstants::PaymentMethodType::APPLE_PAY,
    bank_transfer: PaymentConstants::PaymentMethodType::BANK_TRANSFER,
    other: PaymentConstants::PaymentMethodType::OTHER
  }, prefix: true

  # ===== VALIDATIONS =====
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :status, presence: true

  # ===== SCOPES =====
  scope :active, -> { where(status: PaymentConstants::SubscriptionStatus::ACTIVE) }
  scope :canceled, -> { where(status: PaymentConstants::SubscriptionStatus::CANCELED) }
  scope :past_due, -> { where(status: PaymentConstants::SubscriptionStatus::PAST_DUE) }
  scope :trialing, -> { where(status: PaymentConstants::SubscriptionStatus::TRIALING) }
  scope :paused, -> { where(status: PaymentConstants::SubscriptionStatus::PAUSED) }
  scope :expiring_soon, -> { active.where("current_period_end < ?", 7.days.from_now) }

  # ===== INSTANCE METHODS =====

  # Status helpers
  def active?
    status == "active"
  end

  def canceled?
    status == "canceled"
  end

  def past_due?
    status == "past_due"
  end

  def trialing?
    status == "trialing"
  end

  def paused?
    status == "paused"
  end

  def incomplete?
    status == "incomplete"
  end

  def ended?
    status == "canceled" || ended_at.present?
  end

  def expired?
    status == "incomplete_expired" ||
      status == "canceled" ||
      (ended_at.present? && ended_at <= Time.current)
  end

  def scheduled_for_cancellation?
    cancel_at_period_end? && !ended?
  end

  def renewing?
    active? && !scheduled_for_cancellation?
  end

  def cancelable?
    %w[active trialing].include?(status) &&
      !scheduled_for_cancellation? &&
      !ended?
  end

  # Billing helpers
  def days_until_period_end
    return nil unless current_period_end.present?
    return 0 if current_period_end <= Time.current

    ((current_period_end - Time.current) / 1.day).ceil
  end

  def days_until_renewal
    return nil unless renewing?

    days_until_period_end
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
