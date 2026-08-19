require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user, name: "Old Name") }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  it "localizes update success messages from X-Locale" do
    grant_admin_user_permission(:update)

    patch "/v1/admin/users/#{user.id}",
          params: { user: { name: "New Name" } },
          headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_updated", locale: :my))
  end

  it "localizes create success messages from X-Locale" do
    grant_admin_user_permission(:create)

    post "/v1/admin/users",
         params: { user: valid_user_params },
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:created)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_created", locale: :my))
  end

  it "localizes delete success messages from X-Locale" do
    grant_admin_user_permission(:delete)

    delete "/v1/admin/users/#{user.id}", headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_deleted", locale: :my))
  end

  it "localizes user validation errors from X-Locale" do
    grant_admin_user_permission(:create)
    create(:user, email: "duplicate@example.com")

    post "/v1/admin/users",
         params: { user: valid_user_params.merge(email: "duplicate@example.com") },
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_create_failed", locale: :my))
    expect(response_status["error"]).to include("အီးမေးလ်")
    expect(response_status["error"]).to include("အသုံးပြုပြီးသား")
  end

  def valid_user_params
    {
      email: "created@example.com",
      username: "created_user",
      name: "Created User",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  def grant_admin_user_permission(action)
    role = admin.roles.find_by!(name: "admin")
    permission = Iam::Permission.find_or_create_by!(action: action.to_s, resource: "users")

    Iam::RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end
