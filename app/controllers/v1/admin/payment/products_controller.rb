class V1::Admin::Payment::ProductsController < V1::ApplicationController
  before_action :set_active_product, only: %i[show update destroy]
  before_action :set_product_including_discarded, only: :undiscard

  # GET /v1/admin/payment/products
  def index
    products = ::Payment::Product.order(created_at: :desc)
    pagy, records = pagy(:offset, products, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCTS_FETCHED),
      data: ::Payment::ProductSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/products/discarded
  def read_discarded
    products = ::Payment::Product.with_discarded.discarded.order(discarded_at: :desc)
    pagy, records = pagy(:offset, products, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::DISCARDED_PRODUCTS_FETCHED),
      data: ::Payment::ProductSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/products/:id
  def show
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_FETCHED),
      data: ::Payment::ProductSerializer.new(@product).serializable_hash[:data][:attributes]
    )
  end

  # POST /v1/admin/payment/products
  def create
    result = PaymentService::Client.create_product(product_params)
    return render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, result[:error]) if result[:error]

    render_json_response(
      status_code: 201,
      message: payment_message(MessageService::Payment::PRODUCT_CREATED),
      data: ::Payment::ProductSerializer.new(result[:data]).serializable_hash[:data][:attributes]
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # PATCH/PUT /v1/admin/payment/products/:id
  def update
    result = PaymentService::Client.update_product(@product.id, product_params)
    return render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, result[:error]) if result[:error]

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_UPDATED),
      data: ::Payment::ProductSerializer.new(result[:data]).serializable_hash[:data][:attributes]
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # DELETE /v1/admin/payment/products/:id (discard; route retained for API compatibility)
  def destroy
    result = PaymentService::Client.discard_product(@product.id)
    return render_service_error(MessageService::Payment::PRODUCT_DISCARD_FAILED, result[:error]) if result[:error]

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_DISCARDED)
    )
  end

  # POST /v1/admin/payment/products/:id/undiscard
  def undiscard
    result = PaymentService::Client.undiscard_product(@product.id)
    return render_service_error(MessageService::Payment::PRODUCT_RESTORE_FAILED, result[:error]) if result[:error]

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_RESTORED),
      data: ::Payment::ProductSerializer.new(result[:data]).serializable_hash[:data][:attributes]
    )
  end

  private

  def set_active_product
    @product = ::Payment::Product.find(params[:id])
  end

  def set_product_including_discarded
    @product = ::Payment::Product.with_discarded.find(params[:id])
  end

  def product_params
    values = params.require(:product)
                   .permit(:name, :description, :price_unit_amount, :currency, :cycle, :active)
                   .to_h
                   .symbolize_keys

    values
  end

  def render_service_error(message_key, error)
    render_json_response(
      status_code: 422,
      message: payment_message(message_key),
      error: error
    )
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
