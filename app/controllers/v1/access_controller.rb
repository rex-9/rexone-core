# app/controllers/v1/access_controller.rb:
class V1::AccessController < V1::ApplicationController
  # GET /access
  def index
    accesses = AccessService.get_user_access(current_user.id)

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::FETCHED),
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
      message: access_message(MessageService::Access::ACTIVE_FETCHED),
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
      message: access_message(MessageService::Access::CHECK_COMPLETED),
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
        message: access_message(MessageService::Access::UNAUTHORIZED),
        error: access_message(MessageService::Access::NOT_OWNED)
      )
      return
    end

    access.revoke!

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::REVOKED)
    )
  end

  private

  def access_message(key, **options)
    MessageService::Access.t(key, **options)
  end
end
