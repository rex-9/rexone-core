require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, :super_admin) }
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

  it "discards and restores a user with localized messages" do
    grant_admin_user_permission(:delete)

    post "/v1/admin/users/#{user.id}/discard", headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_discarded", locale: :my))
    expect(response_data).to include("id" => user.id, "discarded_at" => be_present)
    expect(User.with_discarded.find(user.id)).to be_discarded

    post "/v1/admin/users/#{user.id}/undiscard", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.user.user_restored"))
    expect(response_data).to include("id" => user.id, "undiscarded_at" => be_present)
    expect(User.find(user.id)).to be_kept
  end

  it "lists discarded users" do
    grant_admin_user_permission(:delete)
    grant_admin_user_permission(:read)
    user.discard!

    get "/v1/admin/users/discarded", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data).to include(hash_including("id" => user.id))
  end

  it "prevents an admin from discarding their own account" do
    grant_admin_user_permission(:delete)

    post "/v1/admin/users/#{admin.id}/discard", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("admin.user.self_lifecycle_protected"))
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

  describe "GET /v1/admin/users/:id" do
    it "shows a user" do
      grant_admin_user_permission(:read)
      get "/v1/admin/users/#{user.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response_data).to include("name" => user.name, "email" => user.email)
    end

    it "returns 404 for non-existent user" do
      grant_admin_user_permission(:read)
      get "/v1/admin/users/nonexistent-uuid", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /v1/admin/users" do
    it "filters users by search query" do
      grant_admin_user_permission(:read)
      create(:user, name: "Alice")
      create(:user, name: "Bob")

      get "/v1/admin/users?search=Alice", headers: headers
      expect(response).to have_http_status(:ok)
      names = response_data.map { |u| u.dig("attributes", "name") }
      expect(names).to include("Alice")
      expect(names).not_to include("Bob")
    end
  end

  describe "POST /v1/admin/users role assignment" do
    it "assigns roles on creation" do
      grant_admin_user_permission(:create)
      role = create(:role, name: "test_role")
      
      post "/v1/admin/users",
           params: { user: valid_user_params.merge(role_ids: [role.id]) },
           headers: headers

      expect(response).to have_http_status(:created)
      created_user = User.find_by(email: valid_user_params[:email])
      expect(created_user.roles).to include(role)
    end
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
    return if admin.super_admin?

    role = admin.roles.find_by!(name: "admin")
    permission = Iam::Permission.find_or_create_by!(action: action.to_s, resource: "users")

    Iam::RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end
