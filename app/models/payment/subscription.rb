# app/models/payment/subscription.rb
# Synced with Stripe Subscription Object
# https://docs.stripe.com/api/subscriptions/object
class Payment::Subscription < ApplicationRecord
  self.table_name = "payment_subscriptions"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product", inverse_of: :subscriptions
  has_one :user_coupon, -> { where(purchase_type: :sbs) },
          class_name: "Payment::UserCoupon",
          foreign_key: :purchase_id,
          dependent: :nullify,
          inverse_of: false
  has_one :coupon, through: :user_coupon, class_name: "Payment::Coupon"

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

  # ===== VALIDATIONS =====
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_subscription_item_id, :stripe_price_id, :currency,
            :interval, :current_period_start, :current_period_end,
            :started_at, presence: true
  validates :status, presence: true
  validates :unit_amount, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :quantity, :interval_count, numericality: { greater_than: 0, only_integer: true }
  validates :currency, format: { with: /\A[a-z]{3}\z/ }
  validates :interval, inclusion: { in: PaymentConstants::BillingInterval::ALL }

  after_destroy :cleanup_stripe_subscription, if: -> { stripe_subscription_id.present? }

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

  def cleanup_stripe_subscription
    return if stripe_subscription_id.blank?

    begin
      Stripe::Subscription.cancel(stripe_subscription_id)
      Rails.logger.info("[Subscription] Canceled Stripe subscription: #{stripe_subscription_id}")
    rescue Stripe::InvalidRequestError => e
      Rails.logger.info("[Subscription] Stripe subscription #{stripe_subscription_id} not found or already canceled: #{e.message}")
    rescue => e
      Rails.logger.warn("[Subscription] Could not cancel Stripe subscription #{stripe_subscription_id}: #{e.message}")
    end
  end
end
