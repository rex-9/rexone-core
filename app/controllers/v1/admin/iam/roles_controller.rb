class V1::Admin::Iam::RolesController < V1::ApplicationController
  before_action :super_admin_required!
  before_action :set_role, only: %i[show update destroy]

  # GET /v1/admin/iam/roles
  def index
    roles = ::Iam::Role.includes(:permissions, :users).order(created_at: :desc)

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::ROLES_RETRIEVED,
      data: {
        roles: ::Iam::RoleSerializer.new(roles).serializable_hash[:data]
      }
    )
  end

  # GET /v1/admin/iam/roles/permissions
  def read_permissions
    permissions = ::Iam::Permission.order(:resource, :action)

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::ROLE_PERMISSIONS_RETRIEVED,
      data: {
        permissions: ::Iam::PermissionSerializer.new(permissions).serializable_hash[:data]
      }
    )
  end

  # GET /v1/admin/iam/roles/:id
  def show
    render_json_response(
      status_code: 200,
      message: AdminApiMessages::ROLE_RETRIEVED,
      data: {
        role: ::Iam::RoleSerializer.new(@role).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /v1/admin/iam/roles
  def create
    role = ::Iam::Role.new(role_params)

    if role.save
      assign_permissions(role) if permission_ids_param_provided?

      render_json_response(
        status_code: 201,
        message: AdminApiMessages::ROLE_CREATED,
        data: {
          role: ::Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::ROLE_CREATE_FAILED,
        error: role.errors.full_messages.to_sentence
      )
    end
  end

  # PATCH/PUT /v1/admin/iam/roles/:id
  def update
    if @role.update(role_params)
      assign_permissions(@role) if permission_ids_param_provided?

      render_json_response(
        status_code: 200,
        message: AdminApiMessages::ROLE_UPDATED,
        data: {
          role: ::Iam::RoleSerializer.new(@role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::ROLE_UPDATE_FAILED,
        error: @role.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /v1/admin/iam/roles/:id
  def destroy
    if @role.system?
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::ROLE_DELETE_FAILED,
        error: "System roles cannot be deleted."
      )
      return
    end

    @role.destroy

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::ROLE_DELETED
    )
  end

  private

  def set_role
    @role = ::Iam::Role.find(params[:id])
  end

  def role_params
    params.permit(:name, :description)
  end

  def permission_ids_param
    params[:permission_ids]
  end

  def permission_ids_param_provided?
    params.key?(:permission_ids)
  end

  def assign_permissions(role)
    permission_ids = Array(permission_ids_param).reject(&:blank?)
    permissions = ::Iam::Permission.where(id: permission_ids)

    role.role_permissions.destroy_all
    permissions.each do |permission|
      role.role_permissions.find_or_create_by!(permission: permission)
    end
  end
end
