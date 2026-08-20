require "rails_helper"

RSpec.describe "V1 IAM Roles API", type: :request do
  let(:super_admin) { create(:user) }
  let(:token) { jwt_for(super_admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(super_admin)
    grant_permissions(super_admin, "roles", :read, :create, :update, :delete)
  end

  describe "GET /v1/iam/roles" do
    it "returns paginated roles" do
      create_list(:role, 3)

      get "/v1/iam/roles", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
    end
  end

  describe "GET /v1/iam/roles/:id" do
    let(:role) { create(:role, name: "editor") }

    it "returns role details" do
      get "/v1/iam/roles/#{role.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("role", "name")).to eq("editor")
    end
  end

  describe "POST /v1/iam/roles" do
    it "creates a new role" do
      expect do
        post "/v1/iam/roles", params: { name: "moderator", description: "Mod role" }, headers: headers
      end.to change(Iam::Role, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response_data.dig("role", "name")).to eq("moderator")
    end
  end

  describe "PUT /v1/iam/roles/:id" do
    let(:role) { create(:role, name: "old_name") }

    it "updates role details" do
      put "/v1/iam/roles/#{role.id}", params: { name: "new_name" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(role.reload.name).to eq("new_name")
    end
  end

  describe "DELETE /v1/iam/roles/:id" do
    it "deletes a custom role" do
      role = create(:role, name: "custom_role", system: false)

      expect do
        delete "/v1/iam/roles/#{role.id}", headers: headers
      end.to change(Iam::Role, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "forbids deleting a system role" do
      system_role = create(:role, name: "admin_role_system", system: true)

      expect do
        delete "/v1/iam/roles/#{system_role.id}", headers: headers
      end.not_to change(Iam::Role, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
