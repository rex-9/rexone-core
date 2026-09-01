# app/controllers/v1/admin/accesses_controller.rb
class V1::Admin::AccessesController < V1::ApplicationController
  before_action :set_access, only: %i[show update destroy]

  # GET /v1/admin/accesses
  def index
    accesses = AccessService.list_for_admin(
      status: params[:status],
      product_id: params[:product_id],
      user_id: params[:user_id],
      search: params[:search]
    )
    pagy, records = pagy(:offset, accesses, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::FETCHED),
      data: AccessSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/accesses/:id
  def show
    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::FETCHED),
      data: AccessSerializer.new(@access).serializable_hash[:data]
    )
  end

  # POST /v1/admin/accesses
  def create
    product = find_product_for_grant!
    users = find_users_for_grant!

    already_granted_users = users.select { |u| AccessService.has_access?(user_id: u.id, product_id: product.id) }

    if already_granted_users.length == users.length
      user_names = already_granted_users.map { |u| u.username.presence || u.email }.join(", ")
      return render_json_response(
        status_code: 422,
        message: access_message(MessageService::Access::ALREADY_GRANTED),
        error: access_message(
          MessageService::Access::ALREADY_GRANTED_WITH_USERS,
          product: product.name,
          users: user_names
        )
      )
    end

    eligible_users = users - already_granted_users

    expires_at = access_params[:expires_at]
    days = access_params[:days]

    if days.present? && expires_at.blank?
      expires_at = days.to_i.days.from_now
    end

    accesses = eligible_users.map do |user|
      AccessService.grant(
        user_id: user.id,
        product_id: product.id,
        expires_at: expires_at
      )
    end

    data = accesses.map { |a| AccessSerializer.new(a).serializable_hash[:data] }

    render_json_response(
      status_code: 201,
      message: access_message(MessageService::Access::GRANTED),
      data: data
    )
  rescue ActiveRecord::RecordNotFound => error
    render_json_response(
      status_code: 404,
      message: access_message(MessageService::Access::NOT_FOUND),
      error: error.message
    )
  rescue ActiveRecord::RecordInvalid => error
    render_json_response(
      status_code: 422,
      message: access_message(MessageService::Access::UNAUTHORIZED),
      error: error.record.errors.full_messages.to_sentence
    )
  end

  # PATCH/PUT /v1/admin/accesses/:id
  def update
    if @access.expires_at.nil?
      return render_json_response(
        status_code: 422,
        message: access_message(MessageService::Access::CANNOT_EXTEND_LIFETIME),
        error: access_message(MessageService::Access::CANNOT_EXTEND_LIFETIME)
      )
    end

    days = access_params[:days]
    expires_at = access_params[:expires_at]

    access = AccessService.extend_access(
      access: @access,
      days: days,
      expires_at: expires_at
    )

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::EXTENDED),
      data: AccessSerializer.new(access).serializable_hash[:data]
    )
  end

  # DELETE /v1/admin/accesses/:id
  def destroy
    @access.revoke!

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::REVOKED)
    )
  end

  private

  def set_access
    @access = Access.find(params[:id])
  end

  def find_product_for_grant!
    code = access_params[:code]
    product_id = access_params[:product_id]

    if code.present?
      Payment::Product.find_by!(code: code)
    elsif product_id.present?
      Payment::Product.find(product_id)
    else
      raise ActiveRecord::RecordNotFound, access_message(MessageService::Access::PRODUCT_NOT_FOUND)
    end
  end

  def find_users_for_grant!
    raw_emails = access_params[:emails].presence
    raw_usernames = access_params[:usernames].presence
    user_id = access_params[:user_id]

    if raw_emails.present? || raw_usernames.present?
      email_list = parse_identifier_list(raw_emails)
      username_list = parse_identifier_list(raw_usernames)

      users = User.none
      users = users.or(User.where(email: email_list)) if email_list.present?
      users = users.or(User.where(username: username_list)) if username_list.present?
      users = users.to_a

      raise ActiveRecord::RecordNotFound, access_message(MessageService::Access::USERS_NOT_FOUND) if users.empty?

      users
    elsif user_id.present?
      [ User.find(user_id) ]
    else
      raise ActiveRecord::RecordNotFound, access_message(MessageService::Access::USER_NOT_FOUND)
    end
  end

  def parse_identifier_list(raw)
    return [] if raw.blank?

    if raw.is_a?(Array)
      raw.flat_map { |item| item.to_s.split(/[,\n]/) }.map(&:strip).reject(&:blank?)
    else
      raw.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?)
    end
  end

  def access_params
    params.require(:access).permit(
      :user_id,
      :product_id,
      :code,
      :expires_at,
      :days,
      :status,
      emails: [],
      usernames: []
    )
  end

  def access_message(key, **options)
    MessageService::Access.t(key, **options)
  end
end
