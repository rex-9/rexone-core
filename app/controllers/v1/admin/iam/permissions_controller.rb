# app/controllers/v1/admin/iam/permissions_controller.rb
class V1::Admin::Iam::PermissionsController < V1::ApplicationController
  before_action :super_admin_required!
  before_action :set_active_permission, only: %i[show update discard]
  before_action :set_permission_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/iam/permissions
  def index
    filters = index_params
    permissions = if filters[:discarded].to_s == "true"
      ::Iam::Permission.with_discarded.discarded.order(:resource, :action)
    else
      ::Iam::Permission.order(:resource, :action)
    end
    pagy, records = pagy(permissions, limit: filters[:limit])
    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::PERMISSIONS_FETCHED),
      data: ::Iam::PermissionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # POST /v1/admin/iam/permissions/:id/discard
  def discard
    @permission.discard!

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::PERMISSION_DISCARDED)
    )
  end

  # POST /v1/admin/iam/permissions/:id/undiscard
  def undiscard
    @permission.undiscard!

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::PERMISSION_RESTORED),
      data: ::Iam::PermissionSerializer.new(@permission).serializable_hash[:data][:attributes]
    )
  end

  # GET /v1/admin/iam/permissions/:id
  def show
    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::PERMISSION_FETCHED),
      data: ::Iam::PermissionSerializer.new(@permission).serializable_hash[:data][:attributes]
    )
  end

  # POST /v1/admin/iam/permissions
  def create
    permission = ::Iam::Permission.new(permission_params)
    set_permission_name(permission)

    if permission.save
      render_json_response(
        status_code: 201,
        message: iam_message(MessageService::Iam::PERMISSION_CREATED),
        data: ::Iam::PermissionSerializer.new(permission).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::PERMISSION_CREATE_FAILED),
        error: permission.errors.full_messages.to_sentence
      )
    end
  end

  # PATCH/PUT /v1/admin/iam/permissions/:id
  def update
    @permission.assign_attributes(permission_params)
    set_permission_name(@permission)

    if @permission.save
      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::PERMISSION_UPDATED),
        data: ::Iam::PermissionSerializer.new(@permission).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::PERMISSION_UPDATE_FAILED),
        error: @permission.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /v1/admin/iam/permissions/:id
  def destroy
    unless @permission.discarded?
      message = iam_message(MessageService::Iam::PERMISSION_NOT_DISCARDED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    unless @permission.destroy
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::PERMISSION_DELETE_FAILED),
        error: @permission.errors.full_messages.to_sentence
      )
      return
    end

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::PERMISSION_DELETED)
    )
  end

  private

  def index_params
    params.permit(:discarded, :limit, :page)
  end

  def set_active_permission
    @permission = ::Iam::Permission.find(params.permit(:id)[:id])
  end

  def set_permission_including_discarded
    @permission = ::Iam::Permission.with_discarded.find(params.permit(:id)[:id])
  end

  def permission_params
    params.permit(:name, :action, :resource)
  end

  def set_permission_name(permission)
    return if permission.action.blank? || permission.resource.blank?

    permission.name = "#{permission.action}_#{permission.resource}"
  end

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end
end
