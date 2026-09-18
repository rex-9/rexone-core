# frozen_string_literal: true

require "administrate/base_dashboard"

class Payment::UserCouponDashboard < Administrate::BaseDashboard
  def display_resource(user_coupon)
    "Redemption ##{user_coupon.id}"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    coupon: Field::BelongsTo.with_options(class_name: "Payment::Coupon"),
    user: Field::BelongsTo,
    product: Field::BelongsTo.with_options(class_name: "Payment::Product"),
    purchase_id: Field::String,
    purchase_type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    discount_amount: Field::Number,
    original_amount: Field::Number,
    final_amount: Field::Number,
    currency: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    coupon
    user
    product
    discount_amount
    final_amount
    purchase_type
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    coupon
    user
    product
    purchase_id
    purchase_type
    discount_amount
    original_amount
    final_amount
    currency
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    coupon
    user
    product
    purchase_id
    purchase_type
    discount_amount
    original_amount
    final_amount
    currency
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
