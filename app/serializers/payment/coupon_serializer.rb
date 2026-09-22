# frozen_string_literal: true

# app/serializers/payment/coupon_serializer.rb
class Payment::CouponSerializer < ApplicationSerializer
  attributes :id, :title, :description, :code, :coupon_type, :amount, :currency,
             :max_usage, :max_usage_per_user, :used_count, :expires_at, :referrer_id,
             :target_role_ids, :target_user_ids, :target_product_ids,
             :stripe_coupon_id, :active, :metadata, :created_at, :updated_at,
             :discarded_at, :undiscarded_at

  attribute :percentage do |coupon|
    coupon.percentage?
  end

  attribute :fixed do |coupon|
    coupon.fixed?
  end

  attribute :expired do |coupon|
    coupon.expired?
  end

  attribute :exhausted do |coupon|
    coupon.exhausted?
  end

  attribute :referrer_name do |coupon|
    coupon.referrer&.name
  end

  attribute :referrer_username do |coupon|
    coupon.referrer&.username
  end

  attribute :target_role_names do |coupon|
    if coupon.target_role_ids.present? && coupon.target_role_ids.any?
      Iam::Role.where(id: coupon.target_role_ids).pluck(:name)
    else
      []
    end
  end

  attribute :target_product_names do |coupon|
    if coupon.target_product_ids.present? && coupon.target_product_ids.any?
      Payment::Product.where(id: coupon.target_product_ids).pluck(:name)
    else
      []
    end
  end

  attribute :target_user_emails do |coupon|
    if coupon.target_user_ids.present? && coupon.target_user_ids.any?
      User.where(id: coupon.target_user_ids).pluck(:email)
    else
      []
    end
  end
end
