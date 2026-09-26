class V1::Admin::Payment::ProductsController < V1::ApplicationController
  before_action :set_active_product, only: %i[show update discard]
  before_action :set_product_including_discarded, only: :undiscard

  # GET /v1/admin/payment/products
  def index
    discarded = filter_params[:discarded].to_s == "true"
    products = discarded ? ::Payment::Product.with_discarded.discarded : ::Payment::Product.all
    products = if discarded
      sort(products, columns: SortConstants::Columns::PRODUCT, default_column: :discarded_at)
    else
      sort(products, columns: SortConstants::Columns::PRODUCT)
    end
    pagy, records = pagy(products)

    render_json_response(
      status_code: 200,
      message: payment_message(
        discarded ? MessageService::Payment::DISCARDED_PRODUCTS_FETCHED : MessageService::Payment::PRODUCTS_FETCHED
      ),
      **::Payment::ProductSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/payment/products/:id
  def show
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_FETCHED),
      data: ::Payment::ProductSerializer.record(@product)
    )
  end

  # POST /v1/admin/payment/products
  def create
    result = PaymentService::Client.create_product(product_params.except(:thumbnail_asset_id))
    return render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, result[:error]) if result[:error]

    product = result[:data]
    if thumbnail_param_provided? && product.respond_to?(:persisted?) && product.persisted?
      assign_thumbnail(product)
      product.reload
    end

    render_json_response(
      status_code: 201,
      message: payment_message(MessageService::Payment::PRODUCT_CREATED),
      data: ::Payment::ProductSerializer.record(product)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_CREATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # PATCH/PUT /v1/admin/payment/products/:id
  def update
    result = PaymentService::Client.update_product(@product.id, product_params.except(:thumbnail_asset_id))
    return render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, result[:error]) if result[:error]

    product = result[:data]
    if thumbnail_param_provided? && product.respond_to?(:persisted?) && product.persisted?
      assign_thumbnail(product)
      product.reload
    end

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::PRODUCT_UPDATED),
      data: ::Payment::ProductSerializer.record(product)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_service_error(MessageService::Payment::PRODUCT_UPDATE_FAILED, error.record.errors.full_messages.to_sentence)
  end

  # POST /v1/admin/payment/products/:id/discard
  def discard
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
      data: ::Payment::ProductSerializer.record(result[:data])
    )
  end

  private

  def set_active_product
    @product = ::Payment::Product.find(id_params[:id])
  end

  def set_product_including_discarded
    @product = ::Payment::Product.with_discarded.find(id_params[:id])
  end

  def filter_params
    params.permit(:discarded)
  end

  def id_params
    params.permit(:id)
  end

  def product_params
    params.require(:product)
          .permit(:code, :name, :description, :unit_amount, :currency, :interval, :active, :thumbnail_asset_id)
          .to_h
          .symbolize_keys
  end

  def thumbnail_param_provided?
    product_params.key?(:thumbnail_asset_id)
  end

  def assign_thumbnail(product)
    thumbnail_asset_id = product_params[:thumbnail_asset_id]

    if thumbnail_asset_id.present?
      asset = Asset.find(thumbnail_asset_id)
      old_thumbnails = product.assets.where(type: AssetConstants::AssetType::THUMBNAIL).where.not(id: asset.id)
      Asset.purge_and_destroy_all!(old_thumbnails)
      asset.update!(assetable: product, type: AssetConstants::AssetType::THUMBNAIL)
    else
      Asset.purge_and_destroy_all!(product.assets.where(type: AssetConstants::AssetType::THUMBNAIL))
    end
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
