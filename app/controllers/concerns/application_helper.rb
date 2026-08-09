# app/controllers/concerns/application_helper.rb

module ApplicationHelper
  def render_json_response(status_code:, message:, error: nil, data: nil)
    success = status_code == 200 || status_code == 201
    response = {
      status: {
        code: status_code,
        success: success,
        message: message
      }
    }
    response[:status][:error] = error if error
    response[:data] = data if data

    render json: response, status: map_status_code(status_code)
  end

  private

  def map_status_code(status_code)
    case status_code
    when 200 then :ok
    when 201 then :created
    when 401 then :unauthorized
    when 429 then :too_many_requests
    when 404 then :not_found
    when 422 then :unprocessable_content
    else status_code
    end
  end
end
