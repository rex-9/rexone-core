# app/controllers/concerns/application_helper.rb
module ApplicationHelper
  def render_json_response(status_code:, message:, error: nil, data: nil, pagy: nil)
    success = status_code == 200 || status_code == 201
    response = {
      status: {
        code: status_code,
        success: success,
        message: message
      }
    }

    response[:status][:error] = error if error

    # Handle serialized data (already formatted by serializer)
    if data.is_a?(Hash) && data.key?(:data)
      response[:data] = data[:data] # The serialized data array
      response[:meta] = data[:meta] if data[:meta].present? # The pagination meta
    else
      response[:data] = data if data
    end

    render json: response, status: map_status_code(status_code)
  end

  # {
  #   "status": {
  #     "code": 200,
  #     "success": true,
  #     "message": "Users retrieved successfully"
  #   },
  #   "data": [...],
  #   "meta": {
  #     "pagination": {
  #       "current_page": 1,
  #       "total_pages": 10,
  #       "total_count": 95,
  #       "limit": 10,
  #       "next_page": 2,
  #       "prev_page": null
  #     }
  #   }
  # }

  private

  def map_status_code(status_code)
    case status_code
    when 200 then :ok
    when 201 then :created
    when 401 then :unauthorized
    when 403 then :forbidden
    when 429 then :too_many_requests
    when 404 then :not_found
    when 422 then :unprocessable_content
    when 503 then :service_unavailable
    else status_code
    end
  end
end
