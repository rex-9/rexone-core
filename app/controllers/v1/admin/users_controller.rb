# app/controllers/v1/admin/users_controller.rb
class V1::Admin::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Admin::Users]".freeze

  # GET /users?page=2&limit=25
  def index
    users = User.order(created_at: :desc)
    Rails.logger.info("#{LOG_PREFIX} Query: #{users.to_sql}")

    pagy, records = pagy(:offset, users, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::FETCHED),
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  private

  def admin_user_message(key, **options)
    MessageService::Admin::User.t(key, **options)
  end
end
