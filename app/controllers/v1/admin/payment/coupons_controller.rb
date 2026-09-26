# frozen_string_literal: true

# app/controllers/v1/admin/payment/coupons_controller.rb
class V1::Admin::Payment::CouponsController < V1::ApplicationController
  before_action :set_active_coupon, only: %i[update discard]
  before_action :set_coupon_including_discarded, only: %i[show undiscard destroy read_redemptions]

  # GET /v1/admin/payment/coupons
  def index
    discarded = filter_params[:discarded].to_s == "true"
    coupons = discarded ? ::Payment::Coupon.with_discarded.discarded : ::Payment::Coupon.all
    coupons = coupons.includes(:referrer)

    coupons = coupons.where(coupon_type: filter_params[:coupon_type]) if filter_params[:coupon_type].present?
    coupons = coupons.where(currency: filter_params[:currency]) if filter_params[:currency].present?
    coupons = coupons.where(active: ActiveModel::Type::Boolean.new.cast(filter_params[:active])) unless filter_params[:active].nil?

    coupons = search(coupons, search_term: filter_params[:search])
    coupons = if discarded
      sort(coupons, columns: SortConstants::Columns::COUPON, default_column: :discarded_at)
    else
      sort(coupons, columns: SortConstants::Columns::COUPON, default_column: :created_at)
    end

    pagy, records = pagy(:offset, coupons, limit: filter_params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(
        discarded ? MessageService::Payment::DISCARDED_COUPONS_FETCHED : MessageService::Payment::COUPONS_FETCHED
      ),
      **::Payment::CouponSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/payment/coupons/:id
  def show
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::COUPON_FETCHED),
      data: ::Payment::CouponSerializer.record(@coupon)
    )
  end

  # POST /v1/admin/payment/coupons
  def create
    attributes = coupon_params.to_h.symbolize_keys
    attributes[:created_by_id] = current_user.id
    attributes[:updated_by_id] = current_user.id
    resolve_target_user_ids!(attributes)

    result = PaymentService::Client.create_coupon(attributes)
    return render_service_error(MessageService::Payment::COUPON_CREATE_FAILED, result[:error]) if result[:error]

    coupon = result[:data]
    render_json_response(
      status_code: 201,
      message: payment_message(MessageService::Payment::COUPON_CREATED),
      data: ::Payment::CouponSerializer.record(coupon)
    )
  rescue ActiveRecord::RecordInvalid => e
    render_service_error(MessageService::Payment::COUPON_CREATE_FAILED, e.record.errors.full_messages.to_sentence)
  end

  # POST /v1/admin/payment/coupons/batch
  def create_batch
    max_batch_limit = AppConfig::PAYMENT_BATCH_COUPON_LIMIT.positive? ? AppConfig::PAYMENT_BATCH_COUPON_LIMIT : PaymentConstants::Batch::MAX_COUPONS

    count = batch_params[:count].to_i
    count = 10 if count <= 0
    count = [ count, max_batch_limit ].min # Configurable cap (default 100)
    prefix = batch_params[:prefix].to_s.strip.upcase.gsub(/[^A-Z0-9]/, "")

    base_attributes = coupon_params.to_h.symbolize_keys
    base_attributes[:created_by_id] = current_user.id
    base_attributes[:updated_by_id] = current_user.id
    base_attributes[:active] = false
    base_attributes[:metadata] = (base_attributes[:metadata] || {}).merge(
      "status" => PaymentConstants::SyncStatus::PROCESSING
    )
    resolve_target_user_ids!(base_attributes)

    created_coupons = []
    ActiveRecord::Base.transaction do
      count.times do
        code = loop do
          random_part = SecureRandom.alphanumeric(8).upcase.gsub(/[^A-Z0-9]/, "")
          candidate = "#{prefix}#{random_part}"
          break candidate unless ::Payment::Coupon.exists?(code: candidate)
        end

        attrs = base_attributes.merge(code: code)
        created_coupons << ::Payment::Coupon.create!(attrs)
      end
    end

    created_coupons.map(&:id).each_slice(50) do |coupon_ids_slice|
      Payment::SyncBatchCouponsJob.perform_later(coupon_ids_slice)
    end

    render_json_response(
      status_code: 201,
      message: payment_message(MessageService::Payment::BATCH_COUPONS_CREATED),
      data: ::Payment::CouponSerializer.collection(created_coupons)
    )

  rescue ActiveRecord::RecordInvalid => e
    render_service_error(MessageService::Payment::BATCH_COUPONS_CREATE_FAILED, e.record.errors.full_messages.to_sentence)
  rescue => e
    render_service_error(MessageService::Payment::BATCH_COUPONS_CREATE_FAILED, e.message)
  end

  # PUT /v1/admin/payment/coupons/:id
  def update
    attributes = coupon_update_params.to_h.symbolize_keys
    attributes[:updated_by_id] = current_user.id
    resolve_target_user_ids!(attributes)

    result = PaymentService::Client.update_coupon(@coupon.id, attributes)
    return render_service_error(MessageService::Payment::COUPON_UPDATE_FAILED, result[:error]) if result[:error]

    coupon = result[:data]
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::COUPON_UPDATED),
      data: ::Payment::CouponSerializer.record(coupon)
    )
  rescue ActiveRecord::RecordInvalid => e
    render_service_error(MessageService::Payment::COUPON_UPDATE_FAILED, e.record.errors.full_messages.to_sentence)
  end

  # DELETE /v1/admin/payment/coupons/:id
  def discard
    result = PaymentService::Client.discard_coupon(@coupon.id)
    return render_service_error(MessageService::Payment::COUPON_DISCARD_FAILED, result[:error]) if result[:error]

    coupon = result[:data]
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::COUPON_DISCARDED),
      data: ::Payment::CouponSerializer.record(coupon)
    )
  end

  # PUT /v1/admin/payment/coupons/:id/undiscard
  def undiscard
    result = PaymentService::Client.undiscard_coupon(@coupon.id)
    return render_service_error(MessageService::Payment::COUPON_RESTORE_FAILED, result[:error]) if result[:error]

    coupon = result[:data]
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::COUPON_RESTORED),
      data: ::Payment::CouponSerializer.record(coupon)
    )
  end

  # GET /v1/admin/payment/coupons/:id/redemptions
  def read_redemptions
    filters = redemptions_params
    records = @coupon.user_coupons.includes(:coupon, :user, :product)
    records = records.where(purchase_type: filters[:purchase_type]) if filters[:purchase_type].present?
    records = search_redemptions(records, search_term: filters[:search])
    records = sort(records, columns: SortConstants::Columns::USER_COUPON, default_column: :created_at)
    pagy, redemptions = pagy(:offset, records, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::USER_COUPONS_FETCHED),
      **::Payment::UserCouponSerializer.paginated(redemptions, pagy)
    )
  end

  # DELETE /v1/admin/payment/coupons/:id
  def destroy
    result = PaymentService::Client.destroy_coupon(@coupon.id)
    return render_service_error(MessageService::Payment::COUPON_DESTROY_FAILED, result[:error]) if result[:error]

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::COUPON_DELETED)
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    render_service_error(MessageService::Payment::COUPON_DESTROY_FAILED, e.message)
  end

  # DELETE /v1/admin/payment/coupons/bin
  def destroy_bin
    scope = ::Payment::Coupon.with_discarded.discarded
    count = scope.count
    scope.find_each do |coupon|
      PaymentService::Client.destroy_coupon(coupon.id)
    end

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::RECYCLE_BIN_EMPTIED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/payment/coupons/discard_batch
  def discard_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::NO_COUPONS_SELECTED),
        error: payment_message(MessageService::Payment::NO_COUPONS_SELECTED)
      )
      return
    end

    scope = ::Payment::Coupon.kept.where(id: ids)
    count = 0
    scope.find_each do |coupon|
      res = PaymentService::Client.discard_coupon(coupon.id)
      count += 1 unless res[:error]
    end

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::BATCH_DISCARDED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/payment/coupons/undiscard_batch
  def undiscard_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::NO_COUPONS_SELECTED),
        error: payment_message(MessageService::Payment::NO_COUPONS_SELECTED)
      )
      return
    end

    scope = ::Payment::Coupon.with_discarded.discarded.where(id: ids)
    count = 0
    scope.find_each do |coupon|
      res = PaymentService::Client.undiscard_coupon(coupon.id)
      count += 1 unless res[:error]
    end

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::BATCH_RESTORED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/payment/coupons/destroy_batch
  def destroy_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::NO_COUPONS_SELECTED),
        error: payment_message(MessageService::Payment::NO_COUPONS_SELECTED)
      )
      return
    end

    scope = ::Payment::Coupon.with_discarded.where(id: ids)
    count = 0
    scope.find_each do |coupon|
      res = PaymentService::Client.destroy_coupon(coupon.id)
      count += 1 unless res[:error]
    end

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::BATCH_DELETED, count: count),
      data: { count: count }
    )
  end

  private

  def permission_resource_name
    IamConstants::Resource::PAYMENT_COUPONS
  end

  def set_active_coupon
    @coupon = ::Payment::Coupon.find(params.permit(:id)[:id])
  end

  def set_coupon_including_discarded
    @coupon = ::Payment::Coupon.with_discarded.find(params.permit(:id)[:id])
  end

  def filter_params
    params.permit(:coupon_type, :currency, :active, :discarded, :search, :limit, :page)
  end

  def redemptions_params
    params.permit(:limit, :page, :search, :sort_by, :sort_order, :purchase_type)
  end

  def batch_params
    params.permit(:count, :prefix, ids: [])
  end

  def coupon_params
    params.require(:coupon).permit(
      :title,
      :description,
      :code,
      :coupon_type,
      :amount,
      :currency,
      :max_usage,
      :max_usage_per_user,
      :expires_at,
      :referrer_id,
      :active,
      metadata: {},
      target_role_ids: [],
      target_user_ids: [],
      target_user_emails: [],
      target_product_ids: []
    )
  end

  def coupon_update_params
    params.require(:coupon).permit(
      :title,
      :description,
      :max_usage_per_user,
      :referrer_id,
      :active,
      metadata: {},
      target_role_ids: [],
      target_user_ids: [],
      target_user_emails: [],
      target_product_ids: []
    )
  end

  def resolve_target_user_ids!(attributes)
    return unless attributes.key?(:target_user_ids) || attributes.key?(:target_user_emails)

    emails = Array(attributes[:target_user_emails]).map(&:to_s).map(&:strip).reject(&:blank?)
    raw_user_inputs = Array(attributes[:target_user_ids]).map(&:to_s).map(&:strip).reject(&:blank?)

    email_inputs, uuid_inputs = raw_user_inputs.partition { |val| val.include?("@") }
    all_emails = (emails + email_inputs).map(&:downcase).uniq

    if all_emails.any?
      found_users = User.where("LOWER(email) IN (?)", all_emails)
      found_map = found_users.index_by { |u| u.email.downcase }
      missing_emails = all_emails - found_map.keys

      if missing_emails.any?
        coupon = ::Payment::Coupon.new
        coupon.errors.add(:target_user_emails, "not found: #{missing_emails.join(', ')}")
        raise ActiveRecord::RecordInvalid.new(coupon)
      end

      attributes[:target_user_ids] = (uuid_inputs + found_users.map(&:id)).uniq
    else
      attributes[:target_user_ids] = uuid_inputs.uniq
    end
    attributes.delete(:target_user_emails)
  end

  def search(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:referrer).where(
      "coupons.code ILIKE :term OR coupons.title ILIKE :term OR users.username ILIKE :term OR users.name ILIKE :term",
      term: term
    )
  end

  def search_redemptions(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:user, :product).where(
      "users.username ILIKE :term OR users.email ILIKE :term OR payment_products.name ILIKE :term",
      term: term
    )
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
