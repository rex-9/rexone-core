require "rails_helper"

RSpec.describe "V1 IAM Permissions API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "permissions", :read)
  end

  describe "GET /v1/iam/permissions/current" do
    it "returns the authenticated user's paginated permissions" do
      assigned_permission = create(:permission, action: "create", resource: "notifications")
      unassigned_permission = create(:permission, action: "update", resource: "notifications")
      role = create(:role, name: "notification_operator")
      Iam::RolePermission.find_or_create_by!(role: role, permission: assigned_permission)
      Iam::UserRole.find_or_create_by!(user: user, role: role)

      get "/v1/iam/permissions/current", params: { limit: 10 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user.iam_fetched"))
      expect(response_data.pluck("id")).to include(assigned_permission.id)
      expect(response_data.pluck("id")).not_to include(unassigned_permission.id)
      expect(response_meta.dig("pagination", "limit")).to eq(10)
    end

    it "requires read permissions permission" do
      user.user_roles.destroy_all

      get "/v1/iam/permissions/current", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("permissions")
    end
  end
end
