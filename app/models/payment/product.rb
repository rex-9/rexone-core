# app/models/payment/product.rb
# Synced with Stripe Product Object & Price Object
# https://docs.stripe.com/api/prices/object
# https://docs.stripe.com/api/products/object
class Payment::Product < ApplicationRecord
  self.table_name = "payment_products"

  has_many :subscriptions,
          class_name: "Payment::Subscription",
          foreign_key: :product_id,
          dependent: :restrict_with_exception # Prevent deleting a Product if it has any connected subscriptions, transactions, or accesses.

  has_many :transactions,
          class_name: "Payment::Transaction",
          foreign_key: :product_id,
          dependent: :restrict_with_exception

  has_many :accesses,
          foreign_key: :product_id,
          dependent: :restrict_with_exception

  # ===== ENUMS =====
  enum :cycle, { monthly: "month", yearly: "year" }, prefix: true
  enum :currency, { usd: "usd" }, prefix: true

  # ===== VALIDATIONS =====
  validates :name, presence: true
  validates :price_unit_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :stripe_product_id, presence: true, uniqueness: true
  validates :stripe_price_id, presence: true, uniqueness: true
  validates :currency, presence: true

  # ===== SCOPES =====
  scope :active, -> { where(active: true) }
  scope :one_time, -> { where(cycle: nil) }
  scope :recurring, -> { where.not(cycle: nil) }

  # ===== INSTANCE METHODS =====
  def recurring?
    cycle.present?
  end

  def free?
    price_unit_amount.to_i.zero?
  end

  def premium?
    !free?
  end

  def display_price
    return "Free" if free?

    format("%s %.2f", currency.upcase, price_unit_amount / 100.0)
  end

  def cycle_in_duration
    return 0.days unless recurring?

    case cycle
    when "monthly" then 30.days
    when "yearly" then 365.days
    else 0.days
    end
  end

  def cycle_in_seconds
    cycle_in_duration.to_i
  end

  # The period of the subscription (e.g., "monthly", "yearly", "one-time")
  def period_label
    return "One-time purchase" unless recurring?
    cycle.humanize.downcase
  end
end
