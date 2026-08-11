# app/controllers/v1/iam/user_roles_controller.rb
class V1::Iam::UserRolesController < V1::ApplicationController
  before_action :admin_required!

  # GET /iam/user_roles?user_id=:user_id
  # Returns all roles assigned to a specific user
  def index
    user = User.find(params[:user_id])

    render_json_response(
      status_code: 200,
      message: "User roles fetched",
      data: {
        user_id: user.id,
        roles: user.roles.map { |r| { id: r.id, name: r.name } }
      }
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
      message: "Role assigned",
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
        message: "Role removed"
      )
    else
      render_json_response(
        status_code: 404,
        message: "User role not found",
        error: "User does not have this role"
      )
    end
  end
end
