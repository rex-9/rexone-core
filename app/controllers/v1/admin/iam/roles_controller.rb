# app/controllers/v1/admin/iam/roles_controller.rb
class V1::Admin::Iam::RolesController < V1::ApplicationController
  before_action :super_admin_required!
  before_action :set_active_role, only: %i[show update discard]
  before_action :set_role_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/iam/roles
  def index
    filters = index_params
    roles = if filters[:discarded].to_s == "true"
      ::Iam::Role.with_discarded.discarded.includes(:permissions)
    else
      ::Iam::Role.kept.includes(:permissions)
    end
    roles = sort(roles, columns: SortConstants::Columns::ROLE)
    pagy, records = pagy(roles, limit: filters[:limit])
    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_ROLES_RETRIEVED),
      **::Iam::RoleSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/iam/roles/:id
  def show
    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_FETCHED),
      data: ::Iam::RoleSerializer.record(@role)
    )
  end

  # POST /v1/admin/iam/roles
  def create
    role = ::Iam::Role.new(role_params.except(:permission_ids))

    if role.save
      assign_permissions(role) if permission_ids_param_provided?

      render_json_response(
        status_code: 201,
        message: iam_message(MessageService::Iam::ROLE_CREATED),
        data: ::Iam::RoleSerializer.record(role)
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::ROLE_CREATE_FAILED),
        error: role.errors.full_messages.to_sentence
      )
    end
  end

  # PATCH/PUT /v1/admin/iam/roles/:id
  def update
    if @role.update(role_params.except(:permission_ids))
      permissions_changed = begin
        permission_ids_param_provided? && assign_permissions(@role)
      rescue ActiveRecord::RecordNotDestroyed => error
        render_json_response(
          status_code: 422,
          message: iam_message(MessageService::Iam::ROLE_UPDATE_FAILED),
          error: error.record.errors.full_messages.to_sentence
        )
        return
      end
      notify_assigned_users(@role) if permissions_changed

      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::ROLE_UPDATED),
        data: ::Iam::RoleSerializer.record(@role)
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::ROLE_UPDATE_FAILED),
        error: @role.errors.full_messages.to_sentence
      )
    end
  end

  # POST /v1/admin/iam/roles/:id/discard
  def discard
    if @role.system?
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_FORBIDDEN),
        error: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_ERROR)
      )
      return
    end

    @role.discard!

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_DELETED)
    )
  end

  # POST /v1/admin/iam/roles/:id/undiscard
  def undiscard
    @role.undiscard!

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_UPDATED),
      data: ::Iam::RoleSerializer.record(@role)
    )
  end

  # DELETE /v1/admin/iam/roles/:id
  def destroy
    if @role.system?
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_FORBIDDEN),
        error: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_ERROR)
      )
      return
    end

    @role.destroy

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_DELETED)
    )
  end

  private

  def index_params
    params.permit(:discarded, :limit, :page)
  end

  def set_active_role
    @role = ::Iam::Role.find(params.permit(:id)[:id])
  end

  def set_role_including_discarded
    @role = ::Iam::Role.with_discarded.find(params.permit(:id)[:id])
  end

  def role_params
    params.permit(:name, :description, permission_ids: [])
  end

  def permission_ids_param
    role_params[:permission_ids]
  end

  def permission_ids_param_provided?
    role_params.key?(:permission_ids)
  end

  def assign_permissions(role)
    permission_ids = Array(permission_ids_param).reject(&:blank?)
    permissions = ::Iam::Permission.where(id: permission_ids)
    current_permission_ids = role.permission_ids.map(&:to_s).sort
    next_permission_ids = permissions.pluck(:id).map(&:to_s).sort

    return false if current_permission_ids == next_permission_ids

    role.role_permissions.where.not(permission_id: next_permission_ids).find_each(&:destroy!)
    permissions.each do |permission|
      role.role_permissions.find_or_create_by!(permission: permission)
    end

    true
  end

  def notify_assigned_users(role)
    role.users.find_each do |user|
      NotificationService::Center.iam_updated(user)
    end
  end

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end

  def admin_user_message(key, **options)
    MessageService::Admin::User.t(key, **options)
  end
end
