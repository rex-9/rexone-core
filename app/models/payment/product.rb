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

  has_many :user_coupons,
          class_name: "Payment::UserCoupon",
          foreign_key: :product_id,
          dependent: :restrict_with_exception

  has_many :assets, as: :assetable, dependent: :nullify

  # ===== ENUMS =====
  enum :interval, {
    day: PaymentConstants::BillingInterval::DAY,
    week: PaymentConstants::BillingInterval::WEEK,
    month: PaymentConstants::BillingInterval::MONTH,
    year: PaymentConstants::BillingInterval::YEAR
  }, prefix: true
  enum :currency, {
    usd: PaymentConstants::Currency::USD,
    mmk: PaymentConstants::Currency::MMK,
    sgd: PaymentConstants::Currency::SGD
  }, prefix: true

  # ===== READONLY & IMMUTABLE ATTRIBUTES =====
  attr_readonly :code

  # ===== VALIDATIONS =====
  validates :code, presence: true, uniqueness: { case_sensitive: true }, format: { with: /\A[A-Za-z0-9]{10}\z/, message: "must be 10 alphanumeric characters" }
  validates :name, presence: true
  validates :unit_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :stripe_product_id, presence: true, uniqueness: true
  validates :stripe_price_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validate :prevent_code_update, on: :update
  validate :prevent_free_to_premium_transition, on: :update
  validate :free_product_must_be_one_time

  before_validation :generate_unique_code, on: :create
  before_validation :normalize_free_product
  # ===== SCOPES =====
  scope :active, -> { where(active: true) }
  scope :one_time, -> { where(interval: nil) }
  scope :recurring, -> { where.not(interval: nil) }

  before_discard :deactivate

  # ===== INSTANCE METHODS =====
  def recurring?
    interval.present?
  end

  def one_time?
    !recurring?
  end

  def free?
    unit_amount.to_i.zero?
  end

  def premium?
    !free?
  end

  def display_price
    return "Free" if free?

    format("%s %.2f", currency.upcase, unit_amount / 100.0)
  end

  def interval_in_duration
    return 0.days unless recurring?

    case interval.to_s
    when PaymentConstants::BillingInterval::DAY then 1.day
    when PaymentConstants::BillingInterval::WEEK then 7.days
    when PaymentConstants::BillingInterval::MONTH then 30.days
    when PaymentConstants::BillingInterval::YEAR then 365.days
    else 0.days
    end
  end

  def interval_in_seconds
    interval_in_duration.to_i
  end

  # The period of the subscription (e.g., "monthly", "yearly", "one-time")
  def period_label
    return "One-time purchase" unless recurring?
    {
      PaymentConstants::BillingInterval::DAY => "daily",
      PaymentConstants::BillingInterval::WEEK => "weekly",
      PaymentConstants::BillingInterval::MONTH => "monthly",
      PaymentConstants::BillingInterval::YEAR => "yearly"
    }.fetch(interval, interval.humanize.downcase)
  end

  def get_thumbnail_url
    assets.find_by(type: AssetConstants::AssetType::THUMBNAIL)&.url
  end

  private

  def generate_unique_code
    return if code.present?

    loop do
      generated = SecureRandom.alphanumeric(10)
      unless self.class.exists?(code: generated)
        self.code = generated
        break
      end
    end
  end

  def prevent_code_update
    if code_changed? && persisted?
      errors.add(:code, "cannot be modified once created")
    end
  end

  def normalize_free_product
    self.interval = nil if free?
  end

  def free_product_must_be_one_time
    if free? && interval.present?
      errors.add(:interval, "Free products must be one-time and cannot have a recurring billing interval")
    end
  end

  def prevent_free_to_premium_transition
    return unless unit_amount_changed?

    if unit_amount_was.to_i.zero? && unit_amount.to_i.positive?
      errors.add(:unit_amount, "Free products cannot be converted to premium products")
    end
  end

  def deactivate
    self.active = false
  end
end
