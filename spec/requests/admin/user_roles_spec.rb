# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin IAM User Roles API", type: :request do
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

  describe "GET /v1/admin/iam/users/:user_id/roles" do
    it "returns roles of a user" do
      create(:user_role, user: target_user, role: role)

      get "/v1/admin/iam/users/#{target_user.id}/roles", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to be >= 1
    end
  end

  describe "GET /v1/admin/iam/roles/:role_id/users" do
    it "returns users of a role" do
      create(:user_role, user: target_user, role: role)

      get "/v1/admin/iam/roles/#{role.id}/users", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to be >= 1
      expect(response_data.pluck("id")).to include(target_user.id)
    end
  end

  describe "POST /v1/admin/iam/users/:user_id/roles" do
    it "assigns a role to a user" do
      expect do
        post "/v1/admin/iam/users/#{target_user.id}/roles", params: { role_id: role.id }, headers: headers
      end.to change(target_user.roles, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "rotates jti and notifies user when a new role is assigned" do
      allow(NotificationService::Center).to receive(:iam_updated)
      old_jti = target_user.jti

      post "/v1/admin/iam/users/#{target_user.id}/roles", params: { role_id: role.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(target_user.reload.jti).not_to eq(old_jti)
      expect(NotificationService::Center).to have_received(:iam_updated).with(target_user).once
    end

    it "does not notify the user when the role is already assigned" do
      create(:user_role, user: target_user, role: role)
      allow(NotificationService::Center).to receive(:iam_updated)

      post "/v1/admin/iam/users/#{target_user.id}/roles", params: { role_id: role.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(NotificationService::Center).not_to have_received(:iam_updated)
    end
  end

  describe "POST /v1/admin/iam/roles/:role_id/users" do
    it "assigns a user to a role via role endpoint" do
      expect do
        post "/v1/admin/iam/roles/#{role.id}/users", params: { user_id: target_user.id }, headers: headers
      end.to change(target_user.roles, :count).by(1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /v1/admin/iam/users/:user_id/roles/:role_id" do
    before do
      create(:user_role, user: target_user, role: role)
    end

    it "removes a role from a user" do
      expect do
        delete "/v1/admin/iam/users/#{target_user.id}/roles/#{role.id}", headers: headers
      end.to change(target_user.roles, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "rotates jti and notifies user when a role is removed" do
      allow(NotificationService::Center).to receive(:iam_updated)
      old_jti = target_user.jti

      delete "/v1/admin/iam/users/#{target_user.id}/roles/#{role.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(target_user.reload.jti).not_to eq(old_jti)
      expect(NotificationService::Center).to have_received(:iam_updated).with(target_user).once
    end

    it "prevents removing the final super admin role" do
      super_admin_role = admin.roles.find_by!(name: IamConstants::Role::SUPER_ADMIN)

      delete "/v1/admin/iam/users/#{admin.id}/roles/#{super_admin_role.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["message"]).to eq(I18n.t("iam.user_roles.last_super_admin_role_protected"))
      expect(admin.reload).to be_super_admin
    end
  end

  describe "DELETE /v1/admin/iam/roles/:role_id/users/:user_id" do
    before do
      create(:user_role, user: target_user, role: role)
    end

    it "removes a user from a role via role endpoint" do
      expect do
        delete "/v1/admin/iam/roles/#{role.id}/users/#{target_user.id}", headers: headers
      end.to change(target_user.roles, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
