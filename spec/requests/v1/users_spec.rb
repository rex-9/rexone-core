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
  end
end
