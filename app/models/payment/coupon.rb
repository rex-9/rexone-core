# frozen_string_literal: true

# app/models/payment/coupon.rb
class Payment::Coupon < ApplicationRecord
  self.table_name = "coupons"

  # ===== ASSOCIATIONS =====
  belongs_to :referrer, class_name: "User", optional: true
  has_many :user_coupons,
           class_name: "Payment::UserCoupon",
           foreign_key: :coupon_id,
           dependent: :destroy

  # ===== ENUMS =====
  enum :coupon_type, PaymentConstants::CouponType::INTEGER_MAPPING, prefix: true
  enum :currency, {
    usd: PaymentConstants::Currency::USD,
    mmk: PaymentConstants::Currency::MMK,
    sgd: PaymentConstants::Currency::SGD
  }, prefix: true

  # ===== VALIDATIONS =====
  validates :title, presence: true
  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { minimum: 6 },
            format: {
              with: /\A[A-Z0-9]+\z/,
              message: "must contain only uppercase letters and numbers (no hyphens or special characters)"
            }
  validates :amount, numericality: { greater_than: 0 }
  validates :coupon_type, presence: true
  validates :max_usage, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_usage_per_user, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_percentage_amount
  validate :validate_fixed_currency_presence
  validate :validate_user_usage_within_max_usage

  # ===== CALLBACKS =====
  before_validation :normalize_code
  before_discard :deactivate

  # ===== SCOPES =====
  scope :active, -> { where(active: true) }
  scope :unexpired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :available, -> { active.unexpired.where("max_usage = 0 OR used_count < max_usage") }
  scope :recent, -> { order(created_at: :desc) }

  # ===== INSTANCE METHODS =====
  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def exhausted?
    max_usage.to_i.positive? && used_count >= max_usage
  end

  def percentage?
    coupon_type_percentage?
  end

  def fixed?
    coupon_type_fixed?
  end

  def calculate_discount(product)
    product_amount = product.unit_amount.to_i
    discount = if percentage?
      (product_amount * (amount / 100.0)).round
    else
      [ amount, product_amount ].min
    end

    final = [ product_amount - discount, 0 ].max
    { discount_amount: discount, final_amount: final }
  end

  def applicable_to?(user:, product:)
    validation = validate_applicability(user: user, product: product)
    validation[:valid]
  end

  def validate_applicability(user:, product:)
    return { valid: false, error: MessageService::Payment::COUPON_INVALID } unless active? && kept?
    return { valid: false, error: MessageService::Payment::COUPON_INVALID } if expired?
    return { valid: false, error: MessageService::Payment::COUPON_INVALID } if exhausted?

    if currency.present? && currency.downcase != product.currency.downcase
      return { valid: false, error: MessageService::Payment::COUPON_CURRENCY_MISMATCH }
    end

    if target_product_ids.present? && target_product_ids.any? && !target_product_ids.include?(product.id)
      return { valid: false, error: MessageService::Payment::COUPON_NOT_APPLICABLE_PRODUCT }
    end

    if target_user_ids.present? && target_user_ids.any? && !target_user_ids.include?(user.id)
      return { valid: false, error: MessageService::Payment::COUPON_NOT_APPLICABLE_USER }
    end

    if target_role_ids.present? && target_role_ids.any?
      user_role_ids = user.role_ids.map(&:to_s)
      matching_roles = user_role_ids & target_role_ids.map(&:to_s)
      if matching_roles.empty?
        return { valid: false, error: MessageService::Payment::COUPON_NOT_APPLICABLE_ROLE }
      end
    end

    if max_usage_per_user.to_i.positive?
      user_usage_count = user_coupons.where(user_id: user.id).count
      if user_usage_count >= max_usage_per_user
        return { valid: false, error: MessageService::Payment::COUPON_INVALID }
      end
    end

    discount_data = calculate_discount(product)
    {
      valid: true,
      coupon: self,
      original_amount: product.unit_amount.to_i,
      discount_amount: discount_data[:discount_amount],
      final_amount: discount_data[:final_amount],
      currency: product.currency
    }
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase if code.present?
  end

  def validate_percentage_amount
    return unless percentage?

    if amount.present? && (amount <= 0 || amount > 100)
      errors.add(:amount, "Percentage discount must be between 1 and 100")
    end
  end

  def validate_fixed_currency_presence
    return unless fixed?

    if currency.blank?
      errors.add(:currency, "Currency must be specified for fixed amount coupons")
    end
  end

  def validate_user_usage_within_max_usage
    return unless max_usage_per_user.to_i.positive? && max_usage.to_i.positive?

    if max_usage_per_user > max_usage
      errors.add(:max_usage_per_user, "cannot exceed maximum total usage limit")
    end
  end

  def deactivate
    self.active = false
  end
end
