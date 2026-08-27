require "rails_helper"

RSpec.describe "V1 IAM Roles API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "roles", :read)
  end

  describe "GET /v1/iam/roles/current" do
    it "returns the authenticated user's paginated roles" do
      assigned_role = create(:role, name: "editor")
      create(:role, name: "unassigned")
      Iam::UserRole.find_or_create_by!(user: user, role: assigned_role)

      get "/v1/iam/roles/current", params: { limit: 10 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user.iam_fetched"))
      expect(response_data.pluck("id")).to include(assigned_role.id)
      expect(response_data.pluck("attributes").map { |attrs| attrs["name"] }).not_to include("unassigned")
      expect(response_meta.dig("pagination", "limit")).to eq(10)
    end

    it "requires read roles permission" do
      user.user_roles.destroy_all

      get "/v1/iam/roles/current", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to include("read")
      expect(response_status["error"]).to include("roles")
    end
  end
end
