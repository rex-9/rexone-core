# app/controllers/v1/iam/user_roles_controller.rb
class V1::Iam::UserRolesController < V1::ApplicationController
  before_action :super_admin_required!

  # GET /iam/user_roles?user_id=:user_id&page=1&limit=10
  # Returns all roles assigned to a specific user
  def index
    user = User.find(params[:user_id])
    roles = user.roles
    pagy, records = pagy(:offset, roles, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::USER_ROLES_FETCHED),
      data: Iam::RoleSerializer.paginated(records, pagy).merge(user_id: user.id),
      pagy: pagy
    )
  end

  # POST /iam/user_roles?user_id=:user_id&role_id=:role_id
  # Assigns a role to a user
  def create
    user = User.find(params[:user_id])
    role = Iam::Role.find(params[:role_id])

    user_role = Iam::UserRole.find_or_create_by!(user: user, role: role)

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_ASSIGNED),
      data: {
        user_role: Iam::UserRoleSerializer.new(user_role).serializable_hash[:data][:attributes]
      }
    )
  end

  # DELETE /iam/user_roles?user_id=:user_id&role_id=:role_id
  # Removes a role from a user
  def destroy
    user = User.find(params[:user_id])
    role = Iam::Role.find(params[:role_id])

    user_role = Iam::UserRole.find_by(user: user, role: role)

    if user_role
      user_role.destroy
      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::ROLE_REMOVED)
      )
    else
      render_json_response(
        status_code: 404,
        message: iam_message(MessageService::Iam::USER_ROLE_NOT_FOUND),
        error: iam_message(MessageService::Iam::USER_ROLE_MISSING)
      )
    end
  end

  private

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end
end
