# app/models/payment/product.rb
# Synced with Stripe Product Object & Price Object
# https://docs.stripe.com/api/prices/object
# https://docs.stripe.com/api/products/object
class Payment::Product < ApplicationRecord
  self.table_name = "payment_products"

  has_many :subscriptions,
          class_name: "Payment::Subscription",
          foreign_key: :product_id,
          dependent: :restrict_with_exception # Prevent deleting a Product if it has any connected subscriptions, purchases, or accesses.

  has_many :purchases,
          class_name: "Payment::Purchase",
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
  validates :currency, presence: true
  validates :stripe_product_id, uniqueness: true, allow_nil: true
  validates :stripe_price_id, uniqueness: true, allow_nil: true
  validates :google_play_product_id, uniqueness: true, allow_nil: true
  validates :app_store_product_id, uniqueness: true, allow_nil: true
  validate :prevent_code_update, on: :update
  validate :prevent_price_mode_transition, on: :update
  validate :free_product_must_be_one_time
  validate :validate_store_identifiers
  validate :validate_stripe_minimum_amount, if: -> { premium? && stripe_price_id.present? }

  before_validation :generate_unique_code, on: :create
  before_validation :normalize_free_product

  # ===== SCOPES =====
  scope :active, -> { where(active: true) }
  scope :one_time, -> { where(interval: nil) }
  scope :recurring, -> { where.not(interval: nil) }
  scope :for_stripe, -> { where.not(stripe_price_id: nil) }
  scope :for_google_play, -> { where.not(google_play_product_id: nil) }
  scope :for_app_store, -> { where.not(app_store_product_id: nil) }
  scope :for_in_app, -> { where.not(google_play_product_id: nil).or(where.not(app_store_product_id: nil)) }

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

  def available_on_stripe?
    stripe_price_id.present?
  end

  def available_on_google_play?
    google_play_product_id.present?
  end

  def available_on_app_store?
    app_store_product_id.present?
  end

  def in_app?
    available_on_google_play? || available_on_app_store?
  end

  def supported_providers
    providers = []
    providers << PaymentConstants::Provider::STRIPE if available_on_stripe?
    providers << PaymentConstants::Provider::GOOGLE_PLAY if available_on_google_play?
    providers << PaymentConstants::Provider::APP_STORE if available_on_app_store?
    providers
  end

  def store_id_for(provider_name)
    case provider_name.to_s
    when PaymentConstants::Provider::STRIPE then stripe_price_id
    when PaymentConstants::Provider::GOOGLE_PLAY then google_play_product_id
    when PaymentConstants::Provider::APP_STORE then app_store_product_id
    end
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
    return unless free?

    self.interval = nil
  end

  def free_product_must_be_one_time
    if free? && interval.present?
      errors.add(:interval, "Free products must be one-time and cannot have a recurring billing interval")
    end
  end

  def validate_store_identifiers
    return if free?

    if stripe_price_id.blank? && google_play_product_id.blank? && app_store_product_id.blank?
      errors.add(:base, "Premium products must define at least one store identifier (Stripe, Google Play, or App Store)")
    end
  end

  def prevent_price_mode_transition
    return unless unit_amount_changed?

    if unit_amount_was.to_i.zero? && unit_amount.to_i.positive?
      errors.add(:unit_amount, "Free products cannot be converted to premium products")
    elsif unit_amount_was.to_i.positive? && unit_amount.to_i.zero?
      errors.add(:unit_amount, "Premium products cannot be converted to free products")
    end
  end

  def validate_stripe_minimum_amount
    return if free? || currency.blank? || unit_amount.blank?

    min_limit = PaymentConstants::StripeMinimumAmount.for(currency)
    if unit_amount < min_limit
      errors.add(:unit_amount, "must be at least #{min_limit} for #{currency.to_s.upcase} to satisfy Stripe minimum charge limits")
    end
  end

  def deactivate
    self.active = false
  end
end
