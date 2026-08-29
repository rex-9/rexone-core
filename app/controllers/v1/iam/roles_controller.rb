# app/controllers/v1/iam/roles_controller.rb:
class V1::Iam::RolesController < V1::ApplicationController
  before_action :super_admin_required!  
  # GET /iam/roles/current
  def read_current_roles
    roles = current_user.roles.includes(:permissions).order(:name)
    pagy, records = pagy(:offset, roles, limit: params[:limit])
    render_json_response(
      status_code: 200,
      message: user_message(MessageService::User::IAM_FETCHED),
      data: Iam::RoleSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  private

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
