require "rails_helper"

RSpec.describe "Password recovery", type: :request do
  before { allow(NotificationService).to receive(:password_reset_email) }

  describe "POST /password/forgot" do
    it "creates a reset token and queues it for the account email" do
      user = create(:user)
      post "/password/forgot", params: { email: user.email }

      expect(response).to have_http_status(:ok)
      expect(user.reload.reset_password_token).to be_present
      expect(NotificationService).to have_received(:password_reset_email).with(
        email: user.email,
        token: be_present
      )
    end

    it "returns not found for an unknown email" do
      post "/password/forgot", params: { email: "missing@example.com" }
      expect(response).to have_http_status(:not_found)
      expect(NotificationService).not_to have_received(:password_reset_email)
    end
  end

  describe "PUT /password/reset" do
    let(:user) { create(:user) }
    let(:raw_token) { user.send_reset_password_instructions }

    it "changes the password with a valid token" do
      put "/password/reset", params: {
        user: { reset_password_token: raw_token, password: "newpassword", password_confirmation: "newpassword" }
      }

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("newpassword")).to be(true)
    end

    it "rejects an invalid token, short password, and mismatched confirmation" do
      invalid_payloads = [
        { reset_password_token: "invalid", password: "newpassword", password_confirmation: "newpassword" },
        { reset_password_token: raw_token, password: "short", password_confirmation: "short" },
        { reset_password_token: raw_token, password: "newpassword", password_confirmation: "different" }
      ]

      invalid_payloads.each do |payload|
        put "/password/reset", params: { user: payload }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "rejects an expired reset token" do
      raw_token
      user.update_columns(reset_password_sent_at: AppConfig::PASSWORD_RESET_WITHIN.ago - 1.second)

      put "/password/reset", params: {
        user: { reset_password_token: raw_token, password: "newpassword", password_confirmation: "newpassword" }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /password/edit" do
    it "redirects the browser to the client reset screen" do
      get "/password/edit", params: { reset_password_token: "raw-token" }
      expect(response).to redirect_to("#{AppConfig::CLIENT_BASE_URL}/password/reset?reset_password_token=raw-token")
    end
  end
end
