require "rails_helper"

RSpec.describe "V1 Users API", type: :request do
  let(:user) { create(:user, name: "Alice", email: "alice@example.com") }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "users", :read)
  end

  describe "GET /v1/users/current" do
    it "returns the authenticated user attributes" do
      get "/v1/users/current", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("user", "email")).to eq("alice@example.com")
      expect(response_data.dig("user", "name")).to eq("Alice")
    end

    it "requires read users permission" do
      user.user_roles.destroy_all

      get "/v1/users/current", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("users")
    end
  end

  describe "GET /v1/users/current/iam" do
    it "returns user attributes along with roles and permissions" do
      get "/v1/users/current/iam", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("user", "roles", "permissions")
    end

    it "requires read users permission" do
      user.user_roles.destroy_all

      get "/v1/users/current/iam", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("users")
    end
  end
end
