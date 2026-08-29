require "rails_helper"

RSpec.describe "V1 IAM User Roles API", type: :request do
  let(:admin) { create(:user) }
  let(:target_user) { create(:user) }
  let(:role) { create(:role, name: "support") }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(admin)
  end

  describe "GET /v1/iam/users/:user_id/roles" do
    it "returns roles of a user" do
      create(:user_role, user: target_user, role: role)

      get "/v1/iam/users/#{target_user.id}/roles", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to be >= 1
    end
  end

  describe "POST /v1/iam/users/:user_id/roles" do
    it "assigns a role to a user" do
      expect do
        post "/v1/iam/users/#{target_user.id}/roles", params: { role_id: role.id }, headers: headers
      end.to change(target_user.roles, :count).by(1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /v1/iam/users/:user_id/roles/:id" do
    before do
      create(:user_role, user: target_user, role: role)
    end

    it "removes a role from a user" do
      expect do
        delete "/v1/iam/users/#{target_user.id}/roles/#{role.id}", params: { role_id: role.id }, headers: headers
      end.to change(target_user.roles, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
