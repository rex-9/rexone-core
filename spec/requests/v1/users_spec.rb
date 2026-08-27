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

  describe "GET /v1/users" do
    it "returns a paginated users list" do
      create_list(:user, 3)

      get "/v1/users", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
    end

    it "searches users by username, name, and email" do
      username_match = create(:user, username: "needle_user", name: "Other", email: "other@example.com")
      name_match = create(:user, username: "other_user", name: "Needle Name", email: "name@example.com")
      email_match = create(:user, username: "email_user", name: "Email", email: "email.needle@example.com")
      create(:user, username: "ignored_user", name: "Ignored", email: "ignored@example.com")

      get "/v1/users", params: { search: "needle" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |record| record.dig("attributes", "id") }).to contain_exactly(
        username_match.id,
        name_match.id,
        email_match.id
      )
    end

    it "requires read users permission" do
      user.user_roles.destroy_all

      get "/v1/users", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("users")
    end
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
