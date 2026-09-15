require "rails_helper"

RSpec.describe "Admin IAM permissions", type: :request do
  let(:admin) { create(:user, :super_admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  it "lists permissions for super admins" do
    create(:permission, action: "create", resource: "notifications")

    get "/v1/admin/iam/permissions", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.fetched"))
    expect(response_data).not_to be_empty
  end

  it "shows a permission" do
    permission = create(:permission, action: "read", resource: "notifications")

    get "/v1/admin/iam/permissions/#{permission.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.fetched_one"))
    expect(response_data["action"]).to eq("read")
    expect(response_data["resource"]).to eq("notifications")
  end

  it "creates, updates, and deletes a permission with localized messages" do
    post "/v1/admin/iam/permissions",
         params: { action: "read", resource: "notifications" },
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:created)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.created", locale: :my))
    expect(response_data["name"]).to eq("create_notifications")
    permission_id = response_data.fetch("id")

    patch "/v1/admin/iam/permissions/#{permission_id}",
          params: { action: "delete", resource: "notifications" },
          headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.updated", locale: :my))
    expect(response_data["name"]).to eq("update_notifications")

    post "/v1/admin/iam/permissions/#{permission_id}/discard", headers: headers.merge("X-Locale" => "my")

    expect do
      delete "/v1/admin/iam/permissions/#{permission_id}", headers: headers.merge("X-Locale" => "my")
    end.to change(Iam::Permission.with_discarded, :count).by(-1)

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.deleted", locale: :my))
  end

  it "rejects permanent deletion until a permission is discarded" do
    permission = create(:permission, action: "read", resource: "notifications")

    delete "/v1/admin/iam/permissions/#{permission.id}", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.not_discarded"))
    expect(permission.reload).to be_kept
  end

  it "returns validation errors for invalid permission input" do
    post "/v1/admin/iam/permissions",
         params: { action: "approve", resource: "unknown" },
         headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.create_failed"))
    expect(response_status["error"]).to be_present
  end

  it "discards, lists, restores, and permanently deletes a permission" do
    permission = create(:permission, action: "read", resource: "notifications")

    post "/v1/admin/iam/permissions/#{permission.id}/discard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(permission.reload).to be_discarded

    get "/v1/admin/iam/permissions", params: { discarded: true }, headers: headers
    expect(response_data.pluck("id")).to include(permission.id)

    post "/v1/admin/iam/permissions/#{permission.id}/undiscard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(permission.reload).to be_kept

    permission.discard!
    expect do
      delete "/v1/admin/iam/permissions/#{permission.id}", headers: headers
    end.to change(Iam::Permission.with_discarded, :count).by(-1)
  end

  it "requires super admin access" do
    normal_admin = create(:user, :admin)
    normal_token = jwt_for(normal_admin)
    allow(CacheService).to receive(:read).and_return(normal_token)

    get "/v1/admin/iam/permissions", headers: authorization_headers(normal_token)

    expect(response).to have_http_status(:forbidden)
  end

  it "returns all permissions as a single page with pagy metadata when no params are provided" do
    [ "users", IamConstants::Resource::IAM_ROLES, "notifications" ].each do |res|
      create(:permission, action: "read", resource: res)
    end

    get "/v1/admin/iam/permissions", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to be >= 3
    expect(response_meta.dig("pagination", "current_page")).to eq(1)
    expect(response_meta.dig("pagination", "total_pages")).to eq(1)
    expect(response_meta.dig("pagination", "total_count")).to be >= 3
  end

  it "returns 404 for a non-existent permission" do
    get "/v1/admin/iam/permissions/#{SecureRandom.uuid}", headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
