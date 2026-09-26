# app/controllers/v1/iam/permissions_controller.rb

class V1::Iam::PermissionsController < V1::ApplicationController
  # GET /iam/permissions/current
  def read_current_permissions
    permissions = current_user.permissions.order(:name)
    pagy, records = pagy(:offset, permissions, limit: index_params[:limit])
    render_json_response(
      status_code: 200,
      message: user_message(MessageService::User::IAM_FETCHED),
      **Iam::PermissionSerializer.paginated(records, pagy)
    )
  end

  private

  def index_params
    params.permit(:limit, :page)
  end

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
