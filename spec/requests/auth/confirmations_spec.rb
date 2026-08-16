require "rails_helper"

RSpec.describe "Email confirmation", type: :request do
  before do
    allow(NotificationService).to receive(:confirmation_email)
    allow(NotificationService).to receive(:welcome)
    allow(CacheService).to receive(:write)
  end

  describe "POST /confirmation/send_code" do
    it "regenerates and delivers a code by email or username" do
      user = create(:user, :unconfirmed)

      [ user.email, user.username ].each do |signin_key|
        post "/confirmation/send_code", params: { signin_key: signin_key }
        expect(response).to have_http_status(:ok)
      end

      expect(user.reload.confirmation_code).to match(/\A\d{6}\z/)
      expect(NotificationService).to have_received(:confirmation_email).twice
    end

    it "rejects an already confirmed account" do
      user = create(:user)
      post "/confirmation/send_code", params: { signin_key: user.email }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found for an unknown account" do
      post "/confirmation/send_code", params: { signin_key: "missing@example.com" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /confirmation/confirm_code" do
    it "confirms, signs in, records the session, and queues the welcome notification" do
      user = create(:user, :unconfirmed)
      user.update_columns(confirmation_code: "123456", confirmation_sent_at: 1.minute.ago)

      post "/confirmation/confirm_code", params: { signin_key: user.email, confirmation_code: "123456" }

      expect(response).to have_http_status(:ok)
      expect(user.reload).to be_confirmed
      expect(response_data["token"]).to be_present
      expect(NotificationService).to have_received(:welcome).with(user_id: user.id, name: user.name)
      expect(CacheService).to have_received(:write).with(
        "active_session:user:#{user.id}:web",
        response_data["token"],
        expires_in: AppConfig::SESSION_TIMEOUT
      )
    end

    it "rejects wrong and expired codes without confirming" do
      user = create(:user, :unconfirmed)
      user.update_columns(confirmation_code: "123456", confirmation_sent_at: AppConfig::CONFIRM_CODE_WITHIN.ago - 1.second)

      [ "wrong", "123456" ].each do |code|
        post "/confirmation/confirm_code", params: { signin_key: user.email, confirmation_code: code }
        expect(response).to have_http_status(:unprocessable_content)
      end
      expect(user.reload).not_to be_confirmed
    end

    it "rejects an unknown account" do
      post "/confirmation/confirm_code", params: { signin_key: "missing", confirmation_code: "123456" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /confirmation" do
    it "confirms a valid Devise token and redirects with the sign-in token" do
      user = create(:user, :unconfirmed)
      raw_token, encrypted_token = Devise.token_generator.generate(User, :confirmation_token)
      user.update_columns(confirmation_token: encrypted_token, confirmation_sent_at: Time.current)

      get "/confirmation", params: { confirmation_token: raw_token }
      expect(response).to redirect_to("#{AppConfig::CLIENT_BASE_URL}/email/confirm?auth_token=#{user.reload.jti}")
      expect(user).to be_confirmed
    end

    it "redirects invalid tokens with an error" do
      get "/confirmation", params: { confirmation_token: "invalid" }
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("#{AppConfig::CLIENT_BASE_URL}/email/confirm?error=")
    end
  end
end
