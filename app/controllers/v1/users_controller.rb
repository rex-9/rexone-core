# app/controllers/v1/users_controller.rb
class V1::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Users]".freeze

  # GET /users/current
  def read_current_user
    if current_user
      render_json_response(
        status_code: 200,
        message: user_message(MessageService::User::CURRENT_FETCHED),
        data: { user: UserSerializer.new(current_user).serializable_hash[:data][:attributes] }
      )
    else
      render_json_response(
        status_code: 401,
        message: user_message(MessageService::User::NOT_AUTHENTICATED),
        error: user_message(MessageService::User::CURRENT_NOT_FOUND)
      )
    end
  end

  # GET /users/current/iam
  def read_current_iam
    render_json_response(
      status_code: 200,
      message: user_message(MessageService::User::IAM_FETCHED),
      data: {
        user: UserSerializer.new(current_user).serializable_hash[:data][:attributes],
        is_admin: current_user.admin?,
        is_super_admin: current_user.super_admin?,
        roles: Iam::RoleSerializer.new(current_user.roles).serializable_hash[:data],
        admin_roles: Iam::RoleSerializer.new(current_user.admin_roles).serializable_hash[:data],
        non_admin_roles: Iam::RoleSerializer.new(current_user.non_admin_roles).serializable_hash[:data],
        permissions: Iam::PermissionSerializer.new(current_user.permissions).serializable_hash[:data],
        admin_permissions: Iam::PermissionSerializer.new(current_user.admin_permissions).serializable_hash[:data],
        non_admin_permissions: Iam::PermissionSerializer.new(current_user.non_admin_permissions).serializable_hash[:data]
      }
    )
  end

  # PUT /users/current
  def update_current_user
    if current_user.update(current_user_params)
      render_json_response(
        status_code: 200,
        message: user_message(MessageService::User::CURRENT_UPDATED),
        data: { user: UserSerializer.new(current_user).serializable_hash[:data][:attributes] }
      )
    else
      render_json_response(
        status_code: 422,
        message: user_message(MessageService::User::CURRENT_UPDATE_FAILED),
        error: current_user.errors.full_messages.to_sentence
      )
    end
  end

  private

  def current_user_params
    params.require(:user).permit(:name, :username)
  end

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
