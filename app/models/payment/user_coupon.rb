# frozen_string_literal: true

# app/models/payment/user_coupon.rb
class Payment::UserCoupon < ApplicationRecord
  self.table_name = "user_coupons"

  # ===== ASSOCIATIONS =====
  belongs_to :coupon, class_name: "Payment::Coupon", inverse_of: :user_coupons
  belongs_to :user, inverse_of: :user_coupons
  belongs_to :product, class_name: "Payment::Product", inverse_of: :user_coupons

  # ===== ENUMS =====
  enum :purchase_type, PaymentConstants::PurchaseType::INTEGER_MAPPING, prefix: true

  # ===== VALIDATIONS =====
  validates :purchase_id, presence: true
  validates :purchase_type, presence: true
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :original_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :final_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  # ===== SCOPES =====
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_coupon, ->(coupon_id) { where(coupon_id: coupon_id) }

  # ===== INSTANCE METHODS =====
  def trx?
    purchase_type_trx?
  end

  def sbs?
    purchase_type_sbs?
  end

  def purchase
    if trx?
      Payment::Transaction.find_by(id: purchase_id)
    else
      Payment::Subscription.find_by(id: purchase_id)
    end
  end
end
