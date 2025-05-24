class ApplicationController < ActionController::API
  # Helper method to render JSON responses
  def render_json_response(status_code:, message:, data: nil)
    success = status_code == 200 || status_code == 201
    response = {
      success: success,
      message: message
    }
    response[:data] = data if data

    render json: response, status: map_status_code(status_code)
  end

  # Helper method to sanitize email addresses from Google sign-in
  def sanitize_email(email)
    local_part = email.split("@").first.downcase
    sanitized_username = local_part.gsub(/[^a-z0-9_]/, "_")
    if User.exists?(username: sanitized_username)
      "#{sanitized_username}_#{format('%06d', SecureRandom.random_number(10**6))}"
    else
      sanitized_username
    end
  end

  private

  def map_status_code(status_code)
    case status_code
    when 200 then :ok
    when 201 then :created
    when 400 then :bad_request
    when 401 then :unauthorized
    when 403 then :forbidden
    when 404 then :not_found
    when 422 then :unprocessable_entity
    when 500 then :internal_server_error
    else status_code
    end
  end
end
