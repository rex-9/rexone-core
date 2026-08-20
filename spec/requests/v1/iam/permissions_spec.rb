require "rails_helper"

RSpec.describe "V1 IAM Permissions API", type: :request do
  let(:super_admin) { create(:user) }
  let(:token) { jwt_for(super_admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(super_admin)
    grant_permissions(super_admin, "permissions", :read, :create, :update, :delete)
  end

  describe "GET /v1/iam/permissions" do
    it "returns paginated permissions" do
      get "/v1/iam/permissions", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to be <= 2
      expect(response_meta.dig("pagination", "limit")).to eq(2)
    end
  end

  describe "GET /v1/iam/permissions/:id" do
    let(:permission) { Iam::Permission.find_or_create_by!(action: "read", resource: "users") }

    it "returns permission attributes" do
      get "/v1/iam/permissions/#{permission.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("permission", "action")).to eq("read")
      expect(response_data.dig("permission", "resource")).to eq("users")
    end
  end

  describe "POST /v1/iam/permissions/:id/discard and undiscard" do
    let(:permission) { Iam::Permission.find_or_create_by!(action: "create", resource: "roles") }

    it "discards and then restores a permission" do
      post "/v1/iam/permissions/#{permission.id}/discard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(permission.reload.discarded?).to be true

      post "/v1/iam/permissions/#{permission.id}/undiscard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(permission.reload.discarded?).to be false
    end
  end

  describe "DELETE /v1/iam/permissions/:id" do
    let!(:permission) { Iam::Permission.find_or_create_by!(action: "delete", resource: "payments") }

    it "permanently deletes a discarded permission" do
      permission.discard!

      expect do
        delete "/v1/iam/permissions/#{permission.id}", headers: headers
      end.to change(Iam::Permission.with_discarded, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "refuses to permanently delete an undiscarded permission" do
      expect do
        delete "/v1/iam/permissions/#{permission.id}", headers: headers
      end.not_to change(Iam::Permission, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
