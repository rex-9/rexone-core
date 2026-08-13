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
        permissions: Iam::PermissionSerializer
          .new(permissions)
          .serializable_hash[:data]
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
        permission: Iam::PermissionSerializer
          .new(permission)
          .serializable_hash[:data][:attributes]
      }
    )
  end

  # GET /iam/permissions/discarded
  def discarded
    permissions = Iam::Permission.with_discarded.discarded

    render_json_response(
      status_code: 200,
      message: "Discarded permissions fetched",
      data: {
        permissions: Iam::PermissionSerializer
          .new(permissions)
          .serializable_hash[:data]
      }
    )
  end

  # GET /iam/permissions/undiscarded
  def undiscarded
    permissions = Iam::Permission.with_discarded
                                  .where.not(undiscarded_at: nil)

    render_json_response(
      status_code: 200,
      message: "Undiscarded permissions fetched",
      data: {
        permissions: Iam::PermissionSerializer
          .new(permissions)
          .serializable_hash[:data]
      }
    )
  end

  # POST /iam/permissions/:id/discard
  def discard
    permission = Iam::Permission.find(params[:id])
    permission.discard!

    render_json_response(
      status_code: 200,
      message: "Permission moved to recycle bin",
      data: {
        permission: Iam::PermissionSerializer
          .new(permission)
          .serializable_hash[:data]
      }
    )
  end

  # POST /iam/permissions/:id/undiscard
  def undiscard
    permission = Iam::Permission.with_discarded.find(params[:id])
    permission.undiscard!

    render_json_response(
      status_code: 200,
      message: "Permission restored",
      data: {
        permission: Iam::PermissionSerializer
          .new(permission)
          .serializable_hash[:data]
      }
    )
  end

  # DELETE /iam/permissions/:id
  #
  # Permanently deletes a permission from the recycle bin.
  def destroy
    permission = Iam::Permission.with_discarded.find(params[:id])

    unless permission.discarded?
      return render_json_response(
        status_code: 422,
        message: "Permission must be in the recycle bin before permanent deletion"
      )
    end

    permission.destroy!

    render_json_response(
      status_code: 200,
      message: "Permission permanently deleted"
    )
  end
end
