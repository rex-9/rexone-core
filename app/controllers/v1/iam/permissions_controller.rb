# app/controllers/v1/iam/permissions_controller.rb
class V1::Iam::PermissionsController < V1::ApplicationController
  before_action :super_admin_required!

  # GET /iam/permissions
  def index
    permissions = Iam::Permission.all

    render_json_response(
      status_code: 200,
      message: "Permissions fetched",
      data: {
        permissions: Iam::PermissionSerializer.new(permissions).serializable_hash[:data]
      }
    )
  end

  # GET /iam/permissions/:id
  def show
    permission = Iam::Permission.find(params[:id])

    render_json_response(
      status_code: 200,
      message: "Permission fetched",
      data: {
        permission: Iam::PermissionSerializer.new(permission).serializable_hash[:data][:attributes]
      }
    )
  end
end
