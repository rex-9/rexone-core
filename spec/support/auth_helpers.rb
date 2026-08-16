module AuthHelpers
  def json_body
    JSON.parse(response.body)
  end

  def response_data
    json_body.fetch("data", {})
  end

  def response_status
    json_body.fetch("status")
  end

  def jwt_for(user)
    AppConfig::JWT_TOKEN.call(user)
  end

  def authorization_headers(token, platform: "web")
    { "Authorization" => "Bearer #{token}", "X-Platform" => platform, "ACCEPT" => "application/json" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
