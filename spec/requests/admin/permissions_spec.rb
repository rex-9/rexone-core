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

    expect do
      delete "/v1/admin/iam/permissions/#{permission_id}", headers: headers.merge("X-Locale" => "my")
    end.to change(Iam::Permission, :count).by(-1)

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.deleted", locale: :my))
  end

  it "returns validation errors for invalid permission input" do
    post "/v1/admin/iam/permissions",
         params: { action: "approve", resource: "unknown" },
         headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.create_failed"))
    expect(response_status["error"]).to be_present
  end

  it "requires super admin access" do
    normal_admin = create(:user, :admin)
    normal_token = jwt_for(normal_admin)
    allow(CacheService).to receive(:read).and_return(normal_token)

    get "/v1/admin/iam/permissions", headers: authorization_headers(normal_token)

    expect(response).to have_http_status(:forbidden)
  end

  it "returns all permissions without pagination when limit is off" do
    ["users", "roles", "notifications"].each do |res|
      create(:permission, action: "read", resource: res)
    end
    
    get "/v1/admin/iam/permissions", params: { limit: "all" }, headers: headers
    
    expect(response).to have_http_status(:ok)
    expect(response_data.size).to be >= 3
    # When pagy is nil, there should be no pagination metadata
    expect(response_meta.dig("pagination")).to be_nil
  end

  it "returns 404 for a non-existent permission" do
    get "/v1/admin/iam/permissions/#{SecureRandom.uuid}", headers: headers
    
    expect(response).to have_http_status(:not_found)
  end
end
