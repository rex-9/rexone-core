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
    incomplete: "incomplete",       # Checkout started but not completed
    active: "active",               # Active and billing
    past_due: "past_due",           # Payment failed, grace period
    canceled: "canceled",           # Subscription has actually ended
    incomplete_expired: "incomplete_expired",  # the first invoice is not paid within 23 hours
    unpaid: "unpaid",               # Payment failed and no retry
    trialing: "trialing",           # In a trial period
    paused: "paused"                # Paused after trial with no pay
  }

  enum :cycle, {
    monthly: "month",
    yearly: "year"
  }, prefix: true

  enum :payment_method_type, {
    card: "card",
    google_pay: "google_pay",
    apple_pay: "apple_pay",
    bank_transfer: "bank_transfer",
    other: "other"
  }, prefix: true

  # ===== VALIDATIONS =====
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :status, presence: true

  # ===== SCOPES =====
  scope :active, -> { where(status: "active") }
  scope :canceled, -> { where(status: "canceled") }
  scope :past_due, -> { where(status: "past_due") }
  scope :trialing, -> { where(status: "trialing") }
  scope :paused, -> { where(status: "paused") }
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
