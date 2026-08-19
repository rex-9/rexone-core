class V1::Admin::Payment::ProductsController < V1::ApplicationController
  before_action :set_product, only: %i[show update destroy]

  # GET /v1/admin/payment/products
  def index
    products = ::Payment::Product.with_discarded.order(created_at: :desc)
    pagy, records = pagy(:offset, products, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCTS_FETCHED),
      data: ::Payment::ProductSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/products/:id
  def show
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_FETCHED),
      data: {
        product: ::Payment::ProductSerializer.new(@product).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /v1/admin/payment/products
  def create
    product = PaymentService::Client.create_product(coerced_product_params)
    return render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, product[:error]) if service_error?(product)

    render_json_response(
      status_code: 201,
      message: payment_message(MessageService::Payment::PRODUCT_CREATED),
      data: {
        product: ::Payment::ProductSerializer.new(product).serializable_hash[:data][:attributes]
      }
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # PATCH/PUT /v1/admin/payment/products/:id
  def update
    product = PaymentService::Client.update_product(@product.id, coerced_product_params)
    return render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, product[:error]) if service_error?(product)

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_UPDATED),
      data: {
        product: ::Payment::ProductSerializer.new(product).serializable_hash[:data][:attributes]
      }
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # DELETE /v1/admin/payment/products/:id
  def destroy
    product = PaymentService::Client.archive_product(@product.id)
    return render_service_error(MessageService::Payment::PRODUCT_DELETE_FAILED, product[:error]) if service_error?(product)

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_DELETED)
    )
  end

  private

  def set_product
    @product = ::Payment::Product.with_discarded.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price_unit_amount, :currency, :cycle, :active)
  end

  def coerced_product_params
    values = product_params.to_h.symbolize_keys
    values[:price_unit_amount] = values[:price_unit_amount].to_i if values.key?(:price_unit_amount)
    values[:active] = ActiveModel::Type::Boolean.new.cast(values[:active]) if values.key?(:active)
    values[:cycle] = nil if values[:cycle].blank?
    values
  end

  def render_service_error(message_key, error)
    render_json_response(
      status_code: 422,
      message: payment_message(message_key),
      error: error
    )
  end

  def service_error?(result)
    result.is_a?(Hash) && result[:error].present?
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
