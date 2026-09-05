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
    it "returns user attributes along with explicit admin and non-admin roles and permissions" do
      feedback_admin_role = create(:role, name: "feedback_admin")
      feedback_perm = create(:permission, action: "read", resource: "feedbacks")
      feedback_admin_role.permissions << feedback_perm
      user.roles << feedback_admin_role

      get "/v1/users/current/iam", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "user",
        "is_admin",
        "is_super_admin",
        "roles",
        "admin_roles",
        "non_admin_roles",
        "permissions",
        "admin_permissions",
        "non_admin_permissions"
      )
      expect(response_data["is_admin"]).to be(true)
      expect(response_data["is_super_admin"]).to be(false)
      expect(response_data["admin_roles"].map { |r| r.dig("attributes", "name") }).to include("feedback_admin")
      expect(response_data["admin_permissions"].map { |p| p.dig("attributes", "name") }).to include("read_feedbacks")
    end

    it "requires read users permission" do
      user.user_roles.destroy_all

      get "/v1/users/current/iam", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("users")
    end
  end

  describe "PUT /v1/users/current" do
    before { grant_permissions(user, "users", :update) }

    it "updates name and username" do
      put "/v1/users/current",
          params: { user: { name: "Alice Updated", username: "alice_new" } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user.current_updated"))
      expect(response_data.dig("user", "name")).to eq("Alice Updated")
      expect(response_data.dig("user", "username")).to eq("alice_new")
      expect(user.reload).to have_attributes(name: "Alice Updated", username: "alice_new")
    end

    it "returns 422 when the username is already taken" do
      create(:user, username: "bob")

      put "/v1/users/current",
          params: { user: { username: "bob" } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["message"]).to eq(I18n.t("user.current_update_failed"))
      expect(response_status["error"]).to match(/taken/i)
      expect(user.reload.username).not_to eq("bob")
    end

    it "ignores non-permitted attributes like email" do
      original_email = user.email

      put "/v1/users/current",
          params: { user: { name: "Only Name", email: "hacker@example.com" } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("user", "name")).to eq("Only Name")
      expect(user.reload.email).to eq(original_email)
    end

    it "requires update users permission" do
      user.user_roles.destroy_all
      grant_permissions(user, "users", :read)

      put "/v1/users/current",
          params: { user: { name: "Nope" } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("update")
      expect(response_status["error"]).to include("users")
    end
  end
end
