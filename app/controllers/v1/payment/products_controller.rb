# app/controllers/v1/payment/products_controller.rb
class V1::Payment::ProductsController < V1::ApplicationController
  # GET /payment/products?page=1&limit=10
  def index
    products = Payment::Product.active.order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, products, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: MessageService::Payment.t(MessageService::Payment::PRODUCTS_FETCHED),
      **Payment::ProductSerializer.paginated(records, pagy)
    )
  end

  # GET /payment/products/:id
  def show
    product = Payment::Product.find(params.permit(:id)[:id])

    render_json_response(
      status_code: 200,
      message: MessageService::Payment.t(MessageService::Payment::PRODUCT_FETCHED),
      data: Payment::ProductSerializer.record(product)
    )
  end

  private

  def index_params
    params.permit(:limit, :page)
  end
end
