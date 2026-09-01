require "rails_helper"

RSpec.describe "Authentication registration", type: :request do
  before do
    create(:role, name: "user")
    allow(NotificationService::Center).to receive(:confirmation_email)
  end

  let(:valid_attributes) do
    {
      username: "new_user",
      name: "New User",
      email: "new@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  describe "POST /signup" do
    it "creates an unconfirmed email account with its default role" do
      expect { post "/signup", params: { user: valid_attributes } }.to change(User, :count).by(1)

      user = User.find_by!(email: "new@example.com")
      expect(response).to have_http_status(:created)
      expect(user).not_to be_confirmed
      expect(user.provider).to eq("email")
      expect(user.name).to eq("New User")
      expect(user.role_names).to eq([ "user" ])
      expect(response_data.dig("user", "email")).to eq(user.email)
      expect(response_data.dig("user", "name")).to eq("New User")
      expect(response_data.dig("user", "encrypted_password")).to be_nil
    end

    it "dispatches a 6-digit confirmation code email upon signup" do
      expect(NotificationService::Center).to receive(:confirmation_email).with(
        email: "new@example.com",
        code: a_string_matching(/\A\d{6}\z/)
      )

      post "/signup", params: { user: valid_attributes }
      expect(response).to have_http_status(:created)
    end

    it "normalizes email whitespace and casing" do
      post "/signup", params: { user: valid_attributes.merge(email: "  NEW@EXAMPLE.COM ") }
      expect(User.last.email).to eq("new@example.com")
    end

    it "rejects duplicate email, duplicate username, unsafe names, missing name, and mismatched passwords" do
      create(:user, email: "taken@example.com", username: "taken_user")

      invalid_sets = [
        valid_attributes.merge(email: "taken@example.com"),
        valid_attributes.merge(username: "TAKEN_USER"),
        valid_attributes.merge(name: "Bad<Name"),
        valid_attributes.except(:name),
        valid_attributes.merge(password_confirmation: "different")
      ]

      invalid_sets.each do |attributes|
        expect { post "/signup", params: { user: attributes } }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response_status["success"]).to be(false)
      end
    end

    it "directs an existing Google account back to Google sign-in" do
      create(:user, :google_provider, email: valid_attributes[:email])

      expect { post "/signup", params: { user: valid_attributes } }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to include(valid_attributes[:email])
    end

    it "handles a missing user payload as a bad request" do
      post "/signup", params: {}
      expect(response).to have_http_status(:bad_request)
    end

    it "localizes validation responses from the request locale" do
      post "/signup", params: { user: valid_attributes.merge(password: "x", password_confirmation: "x") }, headers: { "X-Locale" => "my" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["message"]).to eq(I18n.t("auth.sign_up_failed", locale: :my))
    end
  end

  describe "DELETE /" do
    it "deletes the authenticated account" do
      user = create(:user)
      token = jwt_for(user)
      allow(CacheService).to receive(:read).and_return(token)
      allow(CacheService).to receive(:write)

      expect { delete "/signup", headers: authorization_headers(token) }.to change(User, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "rejects an unauthenticated deletion" do
      delete "/signup"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
