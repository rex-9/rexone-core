# app/controllers/v1/payment/products_controller.rb
class V1::Payment::ProductsController < V1::ApplicationController
  # GET /payment/products?page=1&limit=10
  def index
    products = Payment::Product.active.order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, products, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: MessageService::Payment.t(MessageService::Payment::PRODUCTS_FETCHED),
      data: Payment::ProductSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /payment/products/:id
  def show
    product = Payment::Product.find(params[:id])

    render_json_response(
      status_code: 200,
      message: MessageService::Payment.t(MessageService::Payment::PRODUCT_FETCHED),
      data: Payment::ProductSerializer.new(product).serializable_hash[:data][:attributes]
    )
  end
end
