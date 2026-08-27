# app/controllers/v1/users_controller.rb
class V1::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Users]".freeze

  # GET /v1/users?page=2&limit=25
  def index
    users = search_users(User.includes(:roles)).order(created_at: :desc)
    Rails.logger.info("#{LOG_PREFIX} Query: #{users.to_sql}")

    pagy, records = pagy(:offset, users, limit: params[:limit])
    render_json_response(
      status_code: 200,
      message: user_message(MessageService::User::USERS_RETRIEVED),
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

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
        roles: Iam::RoleSerializer.new(current_user.roles).serializable_hash[:data],
        permissions: Iam::PermissionSerializer.new(current_user.permissions).serializable_hash[:data]
      }
    )
  end

  private

  def search_users(scope)
    search = params[:search].to_s.strip
    return scope if search.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
    scope.where(
      "users.username ILIKE :search OR users.name ILIKE :search OR users.email ILIKE :search",
      search: pattern
    )
  end

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
