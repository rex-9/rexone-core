# app/controllers/v1/payment/products_controller.rb
class V1::Payment::ProductsController < V1::ApplicationController
  # GET /payment/products?page=1&limit=10&search=pro&recurring=true
  def index
    products = Payment::Product.active
    products = search_products(products, search_term: index_params[:search]) if index_params[:search].present?
    if index_params[:recurring].present?
      products = index_params[:recurring].to_s == "true" ? products.recurring : products.one_time
    end
    products = products.order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, products, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: MessageService::Payment.t(MessageService::Payment::PRODUCTS_FETCHED),
      **Payment::ProductSerializer.collection_pagy(records, pagy)
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
    params.permit(:limit, :page, :search, :recurring)
  end

  def search_products(scope, search_term:)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.to_s.strip)}%"
    scope.where("payment_products.name ILIKE :q OR payment_products.description ILIKE :q", q: pattern)
  end
end
