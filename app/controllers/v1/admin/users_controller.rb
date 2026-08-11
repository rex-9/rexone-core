# app/controllers/v1/admin/users_controller.rb
class V1::Admin::UsersController < V1::ApplicationController
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
end
