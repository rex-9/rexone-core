# frozen_string_literal: true

# app/serializers/payment/user_coupon_serializer.rb
class Payment::UserCouponSerializer < ApplicationSerializer
  attributes :id, :coupon_id, :user_id, :product_id, :purchase_id, :purchase_type,
             :discount_amount, :original_amount, :final_amount, :currency,
             :created_at, :updated_at

  attribute :code do |user_coupon|
    user_coupon.coupon&.code
  end

  attribute :title do |user_coupon|
    user_coupon.coupon&.title
  end

  attribute :coupon_type do |user_coupon|
    user_coupon.coupon&.coupon_type
  end

  attribute :coupon_code do |user_coupon|
    user_coupon.coupon&.code
  end

  attribute :coupon_title do |user_coupon|
    user_coupon.coupon&.title
  end

  attribute :user_name do |user_coupon|
    user_coupon.user&.name
  end

  attribute :user_email do |user_coupon|
    user_coupon.user&.email
  end

  attribute :product_name do |user_coupon|
    user_coupon.product&.name
  end

  attribute :purchase_type_label do |user_coupon|
    user_coupon.purchase_type
  end
end
