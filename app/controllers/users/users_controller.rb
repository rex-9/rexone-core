class Users::UsersController < ApplicationController
  before_action :authenticate_user!, except: [ :read_peek_user ]  # Skip authentication for this action

  # GET /users?page=2&limit=25
  def index
    users = User.order(created_at: :desc)
    Rails.logger.info "Users query: #{users.to_sql}"  # See the SQL before execution

    pagy, records = pagy(:offset, users, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: "Users retrieved successfully",
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

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

  # GET /users/peek?email=user@example.com
  def read_peek_user
    email = params[:email]

    if email.blank?
      render_json_response(
        status_code: 400,
        message: "Email parameter is required.",
        error: "Missing email address."
      )
      return
    end

    user = User.find_by(email: email.to_s.downcase.strip)

    render_json_response(
      status_code: 200,
      message: "User existence checked successfully.",
      data: {
        user_exists: user.present?,
        confirmed: user&.confirmed? || false
      }
    )
  end
end
