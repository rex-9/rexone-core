require "rails_helper"

RSpec.describe "Session expiration", type: :request do
  let(:user) do
    create(
      :user,
      email: "session-user@example.com",
      username: "sessionuser",
      password: "password",
      password_confirmation: "password",
      confirmed_at: Time.current
    )
  end

  def auth_headers(token:, platform: "web")
    {
      "Authorization" => "Bearer #{token}",
      "X-Platform" => platform
    }
  end

  def active_session_key(user_id, platform)
    "active_session:user:#{user_id}:#{platform}"
  end

  before do
    PASSWORD_REDIS.del(active_session_key(user.id, "web"))
    PASSWORD_REDIS.del(active_session_key(user.id, "mobile"))
  end

  after do
    PASSWORD_REDIS.del(active_session_key(user.id, "web"))
    PASSWORD_REDIS.del(active_session_key(user.id, "mobile"))
  end

  it "expires older web session when user signs in again on web" do
    old_web_token = AppConfig::JWT_TOKEN.call(user)
    PASSWORD_REDIS.set(active_session_key(user.id, "web"), old_web_token, ex: 1.week.to_i)

    get "/users/current", headers: auth_headers(token: old_web_token, platform: "web")
    expect(response).to have_http_status(:ok)

    # Simulate another signin replacing the active web session token.
    PASSWORD_REDIS.set(active_session_key(user.id, "web"), "replaced-session-token", ex: 1.week.to_i)

    get "/users/current", headers: auth_headers(token: old_web_token, platform: "web")
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("status", "error")).to eq(Messages::ACTIVE_SESSION_NOT_FOUND)
  end

  it "keeps web and mobile sessions independent" do
    web_token = AppConfig::JWT_TOKEN.call(user)
    mobile_token = AppConfig::JWT_TOKEN.call(user)

    PASSWORD_REDIS.set(active_session_key(user.id, "web"), web_token, ex: 1.week.to_i)
    PASSWORD_REDIS.set(active_session_key(user.id, "mobile"), mobile_token, ex: 1.week.to_i)

    get "/users/current", headers: auth_headers(token: web_token, platform: "web")
    expect(response).to have_http_status(:ok)

    get "/users/current", headers: auth_headers(token: mobile_token, platform: "mobile")
    expect(response).to have_http_status(:ok)
  end
end
