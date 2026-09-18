# frozen_string_literal: true

# app/controllers/v1/admin/payment/user_coupons_controller.rb
class V1::Admin::Payment::UserCouponsController < V1::ApplicationController
  # GET /v1/admin/payment/user_coupons
  def index
    filters = filter_params
    user_coupons = ::Payment::UserCoupon.includes(:coupon, :user, :product)

    user_coupons = user_coupons.where(coupon_id: filters[:coupon_id]) if filters[:coupon_id].present?
    user_coupons = user_coupons.where(user_id: filters[:user_id]) if filters[:user_id].present?
    user_coupons = user_coupons.where(product_id: filters[:product_id]) if filters[:product_id].present?
    user_coupons = user_coupons.where(purchase_type: filters[:purchase_type]) if filters[:purchase_type].present?

    user_coupons = search(user_coupons, search_term: filters[:search])
    user_coupons = sort(
      user_coupons,
      columns: SortConstants::Columns::USER_COUPON,
      default_column: :created_at
    )
    pagy, records = pagy(:offset, user_coupons, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::USER_COUPONS_FETCHED),
      data: ::Payment::UserCouponSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/user_coupons/:id
  def show
    user_coupon = ::Payment::UserCoupon.includes(:coupon, :user, :product).find(params.permit(:id)[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::USER_COUPON_FETCHED),
      data: ::Payment::UserCouponSerializer.new(user_coupon).serializable_hash[:data][:attributes]
    )
  end

  private

  def permission_resource_name
    IamConstants::Resource::PAYMENT_USER_COUPONS
  end

  def filter_params
    params.permit(:coupon_id, :user_id, :product_id, :purchase_type, :search, :limit, :page)
  end

  def search(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:coupon, :user, :product).where(
      "coupons.code ILIKE :term OR users.username ILIKE :term OR users.email ILIKE :term OR payment_products.name ILIKE :term",
      term: term
    )
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
