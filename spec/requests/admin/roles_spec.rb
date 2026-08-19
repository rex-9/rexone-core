require "rails_helper"

RSpec.describe "Admin IAM roles", type: :request do
  let(:admin) { create(:user, :super_admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  it "lists roles and permissions for super admins" do
    create(:role, name: "notification_admin")
    create(:permission, action: "create", resource: "notifications")

    get "/v1/admin/iam/roles", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.roles.fetched"))
    expect(response_data.fetch("roles")).not_to be_empty

    get "/v1/admin/iam/roles/permissions", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.permissions.fetched"))
    expect(response_data.fetch("permissions")).not_to be_empty
  end

  it "creates, updates, and deletes a custom role with localized messages" do
    permission = create(:permission, action: "read", resource: "notifications")

    post "/v1/admin/iam/roles",
         params: {
           name: "notification_admin",
           description: "Notification operators",
           permission_ids: [ permission.id ]
         },
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:created)
    expect(response_status["message"]).to eq(I18n.t("iam.roles.created", locale: :my))
    role_id = response_data.dig("role", "id")

    patch "/v1/admin/iam/roles/#{role_id}",
          params: { description: "Notification admins", permission_ids: [] },
          headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.roles.updated", locale: :my))

    delete "/v1/admin/iam/roles/#{role_id}", headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("iam.roles.deleted", locale: :my))
  end

  it "rejects system role deletion with i18n messages" do
    role = create(:role, name: "system_admin", system: true)

    delete "/v1/admin/iam/roles/#{role.id}", headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("iam.roles.system_delete_forbidden", locale: :my))
    expect(response_status["error"]).to eq(I18n.t("iam.roles.system_delete_error", locale: :my))
  end

  it "requires super admin access" do
    normal_admin = create(:user, :admin)
    normal_token = jwt_for(normal_admin)
    allow(CacheService).to receive(:read).and_return(normal_token)

    get "/v1/admin/iam/roles", headers: authorization_headers(normal_token)

    expect(response).to have_http_status(:forbidden)
  end
end
