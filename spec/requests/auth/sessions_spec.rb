require "rails_helper"

RSpec.describe "Authentication sessions", type: :request do
  before do
    allow(NotificationService).to receive(:sign_in_alert)
    allow(NotificationService).to receive(:confirmation_email)
    allow(CacheService).to receive(:write)
    allow(CacheService).to receive(:delete)
  end

  describe "GET /peek" do
    it "requires an email" do
      get "/peek"
      expect(response).to have_http_status(:bad_request)
    end

    it "normalizes the email and reports confirmation state" do
      create(:user, email: "known@example.com")
      get "/peek", params: { email: " KNOWN@EXAMPLE.COM " }

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("user_exists" => true, "confirmed" => true)
    end

    it "does not reveal anything beyond existence and confirmation" do
      get "/peek", params: { email: "missing@example.com" }
      expect(response_data).to eq("user_exists" => false, "confirmed" => false)
    end
  end

  describe "POST /signin" do
    let(:user) { create(:user, email: "login@example.com", username: "login_user") }
    let(:limiter) { instance_double(PasswordService, allowed?: true, record_success: true) }

    before { allow(PasswordService).to receive(:new).and_return(limiter) }

    it "signs in by email, records the active web session, and queues an alert" do
      post "/signin", params: { user: { signin_key: user.email, password: "password123" } }

      expect(response).to have_http_status(:ok)
      expect(response_data["token"]).to be_present
      expect(response_data.dig("user", "id")).to eq(user.id)
      expect(CacheService).to have_received(:write).with(
        "active_session:user:#{user.id}:web",
        response_data["token"],
        expires_in: AppConfig::SESSION_TIMEOUT
      )
      expect(NotificationService).to have_received(:sign_in_alert).with(user_id: user.id, name: user.name)
    end

    it "signs in by username and isolates android sessions" do
      post "/signin", params: { user: { signin_key: user.username, password: "password123" } }, headers: { "X-Platform" => "android" }
      expect(response).to have_http_status(:ok)
      expect(CacheService).to have_received(:write).with(
        "active_session:user:#{user.id}:android",
        anything,
        expires_in: AppConfig::SESSION_TIMEOUT
      )
    end

    it "signs in by username and isolates ios sessions" do
      post "/signin", params: { user: { signin_key: user.username, password: "password123" } }, headers: { "X-Platform" => "ios" }
      expect(response).to have_http_status(:ok)
      expect(CacheService).to have_received(:write).with(
        "active_session:user:#{user.id}:ios",
        anything,
        expires_in: AppConfig::SESSION_TIMEOUT
      )
    end

    it "rejects an unknown account" do
      post "/signin", params: { user: { signin_key: "missing", password: "password123" } }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns remaining attempts after a wrong password" do
      allow(limiter).to receive(:record_failure).and_return(
        remaining_attempts: 2, cooldown_remaining: 0, cooldown_active: false
      )
      post "/signin", params: { user: { signin_key: user.email, password: "wrong" } }

      expect(response).to have_http_status(:unauthorized)
      expect(response_data).to eq("remaining_attempts" => 2, "cooldown_remaining" => 0)
    end

    it "returns the active cooldown without checking the password" do
      allow(limiter).to receive(:allowed?).and_return(false)
      allow(limiter).to receive(:cooldown_remaining).and_return(24)
      post "/signin", params: { user: { signin_key: user.email, password: "password123" } }

      expect(response).to have_http_status(:too_many_requests)
      expect(response_data).to eq("remaining_attempts" => 0, "cooldown_remaining" => 24)
      expect(limiter).not_to have_received(:record_success)
    end

    it "sends a fresh confirmation code instead of signing in an unconfirmed account" do
      unconfirmed = create(:user, :unconfirmed)
      allow(User).to receive(:find_by).and_return(unconfirmed)

      post "/signin", params: { user: { signin_key: unconfirmed.email, password: "password123" } }

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("otp_sent" => true)
      expect(NotificationService).to have_received(:confirmation_email).twice.with(
        email: unconfirmed.email,
        code: match(/\A\d{6}\z/)
      )
      expect(CacheService).not_to have_received(:write)
    end
  end

  describe "POST /signin/token" do
    it "exchanges a valid JWT token for a session JWT" do
      user = create(:user)
      token = jwt_for(user)
      post "/signin/token", params: { token: token }
      expect(response).to have_http_status(:ok)
      expect(response_data["token"]).to be_present
    end

    it "rejects an invalid token" do
      post "/signin/token", params: { token: "invalid" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "active session enforcement and sign-out" do
    it "accepts and refreshes the matching platform session" do
      user = create(:user)
      grant_users_read_permission(user)
      token = jwt_for(user)
      allow(CacheService).to receive(:read).and_return(token)

      get "/v1/users/current", headers: authorization_headers(token)
      expect(response).to have_http_status(:ok)
      expect(CacheService).to have_received(:write).with(
        "active_session:user:#{user.id}:web", token, expires_in: AppConfig::SESSION_TIMEOUT
      )
    end

    it "rejects a missing or replaced active session" do
      user = create(:user)
      grant_users_read_permission(user)
      token = jwt_for(user)
      allow(CacheService).to receive(:read).and_return(nil, "different-token")

      2.times do
        get "/v1/users/current", headers: authorization_headers(token)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "clears only the matching session during sign-out" do
      user = create(:user)
      token = jwt_for(user)
      allow(CacheService).to receive(:read).and_return(token)

      delete "/signout", headers: authorization_headers(token)
      expect(response).to have_http_status(:ok)
      expect(CacheService).to have_received(:delete).with("active_session:user:#{user.id}:web")
    end

    it "rejects sign-out without authentication" do
      delete "/signout"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "Google sign-in flows" do
    let(:google_user_info) do
      {
        "email" => "google_user@example.com",
        "name" => "Google User",
        "picture" => "https://example.com/avatar.jpg"
      }
    end

    before do
      allow(GoogleAuthService).to receive(:fetch_user_info).and_return(google_user_info)
    end

    it "signs in an existing confirmed user directly" do
      user = create(:user, email: "google_user@example.com", confirmed_at: Time.current)

      post "/signin/google", params: { token: "valid_google_token" }

      expect(response).to have_http_status(:ok)
      expect(response_data["user"]["id"]).to eq(user.id)
      expect(response_data["token"]).to be_present
    end

    it "returns password_required and challenge_token for a new user" do
      post "/signin/google", params: { token: "valid_google_token" }

      expect(response).to have_http_status(:ok)
      expect(response_data["password_required"]).to be true
      expect(response_data["challenge_token"]).to be_present
    end

    it "requires password setup and confirms a user who dropped previous email onboarding without confirming" do
      # 1. Unconfirmed user created via earlier email signup
      unconfirmed_user = create(:user, email: "google_user@example.com", confirmed_at: nil, provider: "email")
      expect(unconfirmed_user.confirmed?).to be false

      # 2. Next time user logs in with Google SSO -> returns challenge token
      post "/signin/google", params: { token: "valid_google_token" }
      expect(response).to have_http_status(:ok)
      expect(response_data["password_required"]).to be true
      challenge_token = response_data["challenge_token"]

      # Stub cache read for null_store in test env
      allow(CacheService).to receive(:read).with("google_signin:challenge:#{challenge_token}").and_return(
        { "email" => "google_user@example.com", "name" => "Google User" }.to_json
      )

      # 3. User sets 6-digit password via google_sign_in_complete
      post "/signin/google/complete", params: { challenge_token: challenge_token, password: "654321" }

      expect(response).to have_http_status(:ok)
      expect(response_data["user"]["id"]).to eq(unconfirmed_user.id)
      expect(response_data["token"]).to be_present

      # 4. User is now confirmed, provider is google, and new password is set
      unconfirmed_user.reload
      expect(unconfirmed_user.confirmed?).to be true
      expect(unconfirmed_user.provider).to eq(AuthConstants::Provider::GOOGLE)
      expect(unconfirmed_user.valid_password?("654321")).to be true
    end
  end

  def grant_users_read_permission(user)
    role = create(:role, name: "session_test_role")
    permission = create(:permission, name: "read_users", action: "read", resource: "users")
    create(:role_permission, role: role, permission: permission)
    Iam::UserRole.create!(user: user, role: role)
  end
end
