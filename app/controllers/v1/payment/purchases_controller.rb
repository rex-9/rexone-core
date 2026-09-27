# frozen_string_literal: true

# app/controllers/v1/payment/purchases_controller.rb
class V1::Payment::PurchasesController < V1::ApplicationController
  # GET /payment/purchases?page=1&limit=10
  def index
    purchases = current_user.purchases.includes(:product).order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, purchases, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PURCHASES_FETCHED),
      **Payment::PurchaseSerializer.collection_pagy(records, pagy)
    )
  end

  # GET /payment/purchases/:id
  def show
    purchase = current_user.purchases.find(purchase_params[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PURCHASE_FETCHED),
      data: Payment::PurchaseSerializer.record(purchase)
    )
  end

  # GET /payment/purchases/recent?page=1&limit=10
  def read_recent
    purchases = current_user.purchases.includes(:product).successful.recent
    pagy, records = pagy(:offset, purchases, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::RECENT_PURCHASES_FETCHED),
      **Payment::PurchaseSerializer.collection_pagy(records, pagy)
    )
  end

  private

  def index_params
    params.permit(:limit, :page)
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

  def purchase_params
    params.permit(:id)
  end
end
