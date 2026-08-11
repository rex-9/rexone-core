# app/controllers/v1/access_controller.rb:
class V1::AccessController < V1::ApplicationController
  # GET /access
  def index
    accesses = AccessService.get_user_access(current_user.id)

    render_json_response(
      status_code: 200,
      message: "Access retrieved",
      data: {
        accesses: AccessSerializer.new(accesses).serializable_hash[:data]
      }
    )
  end

  # GET /access/active
  def read_active
    accesses = AccessService.get_active_access(current_user.id)

    render_json_response(
      status_code: 200,
      message: "Active access retrieved",
      data: {
        accesses: AccessSerializer.new(accesses).serializable_hash[:data]
      }
    )
  end

  # GET /access/check
  def read_check
    product_id = params[:product_id]
    has_access = AccessService.has_access?(
      user_id: current_user.id,
      product_id: product_id
    )

    render_json_response(
      status_code: 200,
      message: "Access check completed",
      data: {
        has_access: has_access,
        product_id: product_id
      }
    )
  end

  # DELETE /access/:id
  def destroy
    access = Access.find(params[:id])

    unless access.user_id == current_user.id
      render_json_response(
        status_code: 403,
        message: "Unauthorized",
        error: "You do not own this access"
      )
      return
    end

    access.revoke!

    render_json_response(
      status_code: 200,
      message: "Access revoked"
    )
  end
end
