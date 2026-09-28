# app/controllers/v1/payment/products_controller.rb
class V1::Payment::ProductsController < V1::ApplicationController
  # GET /payment/products?page=1&limit=10&search=pro&recurring=true
  def index
    products = Payment::Product.active
    products = search_products(products, search_term: index_params[:search]) if index_params[:search].present?
    if index_params[:recurring].present?
      products = index_params[:recurring].to_s == "true" ? products.recurring : products.one_time
    end
    if index_params[:provider].present?
      case index_params[:provider].to_s.downcase
      when PaymentConstants::Provider::STRIPE
        products = products.for_stripe
      when PaymentConstants::Provider::GOOGLE_PLAY
        products = products.for_google_play
      when PaymentConstants::Provider::APP_STORE
        products = products.for_app_store
      when "in_app"
        products = products.for_in_app
      end
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
    params.permit(:limit, :page, :search, :recurring, :provider)
  end

  def search_products(scope, search_term:)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.to_s.strip)}%"
    scope.where("payment_products.name ILIKE :q OR payment_products.description ILIKE :q", q: pattern)
  end
end
