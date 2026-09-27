# frozen_string_literal: true

class V1::Admin::Payment::PurchasesController < V1::ApplicationController
  # GET /v1/admin/payment/purchases
  def index
    filters = filter_params
    purchases = ::Payment::Purchase.includes(:user, :product, user_coupon: :coupon)
    purchases = purchases.where(status: filters[:status]) if filters[:status].present?
    purchases = purchases.where(currency: filters[:currency]) if filters[:currency].present?
    purchases = purchases.where(product_id: filters[:product_id]) if filters[:product_id].present?
    purchases = purchases.where(user_id: filters[:user_id]) if filters[:user_id].present?
    purchases = search(purchases, search_term: filters[:search])
    purchases = sort(
      purchases,
      columns: SortConstants::Columns::PURCHASE,
      default_column: "created_at"
    )
    pagy, records = pagy(:offset, purchases, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PURCHASES_FETCHED),
      **::Payment::PurchaseSerializer.collection_pagy(records, pagy)
    )
  end

  # GET /v1/admin/payment/purchases/:id
  def show
    purchase = ::Payment::Purchase.includes(:user, :product, user_coupon: :coupon).find(params.permit(:id)[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PURCHASE_FETCHED),
      data: ::Payment::PurchaseSerializer.record(purchase)
    )
  end

  private

  def filter_params
    params.permit(:status, :currency, :product_id, :user_id, :search, :limit, :page)
  end

  def search(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:user, :product).where(
      "users.email ILIKE :term OR users.username ILIKE :term OR payment_products.name ILIKE :term " \
      "OR payment_purchases.stripe_payment_intent_id ILIKE :term OR payment_purchases.stripe_charge_id ILIKE :term",
      term: term
    )
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
