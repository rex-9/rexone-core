# app/controllers/v1/users_controller.rb
class V1::UsersController < V1::ApplicationController
  # GET /users/current
  def read_current_user
    if current_user
      render_json_response(
        status_code: 200,
        message: "Current user fetched successfully.",
        data: { user: UserSerializer.new(current_user).serializable_hash[:data][:attributes] }
      )
    else
      render_json_response(
        status_code: 401,
        message: "User not authenticated.",
        error: "No current user found."
      )
    end
  end

  # GET /users/current/iam
  def read_current_iam
    render_json_response(
      status_code: 200,
      message: "User IAM fetched",
      data: {
        user: UserSerializer.new(current_user).serializable_hash[:data][:attributes],
        roles: Iam::RoleSerializer.new(current_user.roles).serializable_hash[:data],
        permissions: Iam::PermissionSerializer.new(current_user.permissions).serializable_hash[:data]
      }
    )
  end
end
