# app/controllers/v1/accesses_controller.rb
class V1::AccessesController < V1::ApplicationController
  # GET /accesses?page=1&limit=10
  def index
    accesses = AccessService.get_user_access(current_user.id)
    pagy, records = pagy(:offset, accesses, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::FETCHED),
      **AccessSerializer.paginated(records, pagy)
    )
  end

  # GET /accesses/active?page=1&limit=10
  def read_active
    accesses = AccessService.get_active_access(current_user.id)
    pagy, records = pagy(:offset, accesses, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: access_message(MessageService::Access::ACTIVE_FETCHED),
      **AccessSerializer.paginated(records, pagy)
    )
  end

  # GET /accesses/check
  def read_check
    product_id = check_params[:product_id]
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

  # DELETE /accesses/:id
  def destroy
    access = Access.find(params.permit(:id)[:id])

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

  def index_params
    params.permit(:limit, :page)
  end

  def check_params
    params.permit(:product_id)
  end

  def access_message(key, **options)
    MessageService::Access.t(key, **options)
  end
end
