# frozen_string_literal: true

require "administrate/base_dashboard"

class Payment::CouponDashboard < Administrate::BaseDashboard
  def display_resource(coupon)
    "#{coupon.title} (#{coupon.code})"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    title: Field::String,
    description: Field::Text,
    code: Field::String,
    coupon_type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    amount: Field::Number,
    currency: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    max_usage: Field::Number,
    max_usage_per_user: Field::Number,
    used_count: Field::Number,
    expires_at: Field::DateTime,
    referrer: Field::BelongsTo.with_options(class_name: "User"),
    stripe_coupon_id: Field::String,
    active: Field::Boolean,
    metadata: Field::String.with_options(searchable: false),
    user_coupons: Field::HasMany.with_options(class_name: "Payment::UserCoupon"),
    discarded_at: Field::DateTime,
    undiscarded_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    code
    title
    coupon_type
    amount
    currency
    used_count
    max_usage
    active
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    description
    code
    coupon_type
    amount
    currency
    max_usage
    max_usage_per_user
    used_count
    expires_at
    referrer
    stripe_coupon_id
    active
    metadata
    user_coupons
    discarded_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    description
    code
    coupon_type
    amount
    currency
    max_usage
    max_usage_per_user
    expires_at
    referrer
    active
    metadata
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
