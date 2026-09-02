require "rails_helper"

RSpec.describe "V1 Admin Accesses API", type: :request do
  let(:super_admin) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:regular_user) { create(:user) }
  let(:target_user) { create(:user) }
  let(:product) { create(:payment_product) }

  let(:super_admin_role) { create(:role, name: IamConstants::Role::SUPER_ADMIN) }
  let(:admin_role) { create(:role, name: IamConstants::Role::ADMIN) }
  let(:user_role) { create(:role, name: IamConstants::Role::USER) }

  let(:super_admin_token) { jwt_for(super_admin) }
  let(:admin_token) { jwt_for(admin_user) }
  let(:regular_user_token) { jwt_for(regular_user) }

  let(:super_admin_headers) { authorization_headers(super_admin_token) }
  let(:admin_headers) { authorization_headers(admin_token) }
  let(:user_headers) { authorization_headers(regular_user_token) }

  before do
    allow(CacheService).to receive(:read).and_call_original
    allow(CacheService).to receive(:read).with("active_session:user:#{super_admin.id}:web").and_return(super_admin_token)
    allow(CacheService).to receive(:read).with("active_session:user:#{admin_user.id}:web").and_return(admin_token)
    allow(CacheService).to receive(:read).with("active_session:user:#{regular_user.id}:web").and_return(regular_user_token)
    allow(CacheService).to receive(:write)

    super_admin.roles << super_admin_role
    admin_user.roles << admin_role
    regular_user.roles << user_role

    grant_admin_permissions(admin_user, "accesses", :read, :create, :update, :delete)
  end

  describe "GET /v1/admin/accesses" do
    before do
      3.times { create(:access, user: create(:user), product: product, status: AccessConstants::AccessStatus::ACTIVE) }
    end

    it "lists accesses for super admins" do
      get "/v1/admin/accesses", params: { page: 1, limit: 20 }, headers: super_admin_headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
      expect(response_meta).to have_key("pagination")
    end

    it "returns all records in a single page when pagination params are omitted" do
      get "/v1/admin/accesses", headers: super_admin_headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
      expect(response_meta["pagination"]).to include(
        "current_page" => 1,
        "total_pages" => 1,
        "total_count" => 3,
        "next_page" => nil,
        "prev_page" => nil
      )
    end

    it "lists accesses for admins with accesses permissions" do
      get "/v1/admin/accesses", headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
    end

    it "rejects non-admin users" do
      get "/v1/admin/accesses", headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "filters accesses by status" do
      create(:access, user: create(:user), product: product, status: AccessConstants::AccessStatus::REVOKED)

      get "/v1/admin/accesses", params: { status: "revoked" }, headers: super_admin_headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "status")).to eq("revoked")
    end
  end

  describe "POST /v1/admin/accesses" do
    let(:valid_params) do
      {
        access: {
          user_id: target_user.id,
          product_id: product.id,
          days: 30
        }
      }
    end

    it "grants access with days duration" do
      post "/v1/admin/accesses", params: valid_params, headers: super_admin_headers

      expect(response).to have_http_status(:created)
      expect(response_data).to be_an(Array)
      expect(response_data.first.dig("attributes", "product_id")).to eq(product.id)
      expect(response_data.first.dig("attributes", "active")).to eq(true)
      expect(target_user.accesses.where(product: product, status: "active")).to exist
    end

    it "grants access to multiple users via emails array and product code" do
      user_two = create(:user, email: "second.user@example.com")

      post "/v1/admin/accesses",
           params: {
             access: {
               code: product.code,
               emails: [ target_user.email, user_two.email ],
               days: 60
             }
           },
           headers: super_admin_headers

      expect(response).to have_http_status(:created)
      expect(target_user.accesses.where(product: product, status: "active")).to exist
      expect(user_two.accesses.where(product: product, status: "active")).to exist
    end

    it "grants access via emails array" do
      user_two = create(:user, email: "comma.user@example.com")

      post "/v1/admin/accesses",
           params: {
             access: {
               code: product.code,
               emails: [ target_user.email, user_two.email ],
               days: 90
             }
           },
           headers: super_admin_headers

      expect(response).to have_http_status(:created)
      expect(target_user.accesses.where(product: product, status: "active")).to exist
      expect(user_two.accesses.where(product: product, status: "active")).to exist
    end

    it "grants access via mixed emails and usernames" do
      user_two = create(:user, username: "valid_username_2", email: "user2@test.com")

      post "/v1/admin/accesses",
           params: {
             access: {
               code: product.code,
               emails: [ target_user.email ],
               usernames: [ user_two.username ],
               days: 45
             }
           },
           headers: super_admin_headers

      expect(response).to have_http_status(:created)
      expect(target_user.accesses.where(product: product, status: "active")).to exist
      expect(user_two.accesses.where(product: product, status: "active")).to exist
    end

    it "returns 404 when username does not match any user" do
      post "/v1/admin/accesses",
           params: {
             access: {
               code: product.code,
               usernames: [ "non_existent_username" ],
               days: 30
             }
           },
           headers: super_admin_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when all users already have an active entitlement" do
      create(:access, user: target_user, product: product, status: "active", expires_at: 30.days.from_now)

      post "/v1/admin/accesses",
           params: {
             access: {
               code: product.code,
               emails: [ target_user.email ],
               days: 30
             }
           },
           headers: super_admin_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).dig("status", "message")).to eq("Access has already been granted to this product")
    end

    it "returns 404 for non-existent product code" do
      post "/v1/admin/accesses",
           params: { access: { emails: [ target_user.email ], code: "INVALID000" } },
           headers: super_admin_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for invalid product" do
      post "/v1/admin/accesses", params: { access: { user_id: target_user.id, product_id: "00000000-0000-0000-0000-000000000000" } }, headers: super_admin_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /v1/admin/accesses/:id" do
    let!(:access) { create(:access, user: target_user, product: product, status: AccessConstants::AccessStatus::ACTIVE, expires_at: 5.days.from_now) }

    it "extends access expiration" do
      patch "/v1/admin/accesses/#{access.id}", params: { access: { days: 30 } }, headers: super_admin_headers

      expect(response).to have_http_status(:ok)
      expect(access.reload.expires_at).to be > 30.days.from_now
    end

    it "returns 422 when attempting to extend lifetime access" do
      other_user = create(:user)
      lifetime_access = create(:access, user: other_user, product: product, status: AccessConstants::AccessStatus::ACTIVE, expires_at: nil)

      patch "/v1/admin/accesses/#{lifetime_access.id}", params: { access: { days: 30 } }, headers: super_admin_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).dig("status", "error")).to eq("Lifetime entitlements cannot be extended because they never expire.")
    end
  end

  describe "DELETE /v1/admin/accesses/:id" do
    let!(:access) { create(:access, user: target_user, product: product, status: AccessConstants::AccessStatus::ACTIVE) }

    it "revokes the user access and sets revoked_at timestamp" do
      delete "/v1/admin/accesses/#{access.id}", headers: super_admin_headers

      expect(response).to have_http_status(:ok)
      expect(access.reload.status).to eq(AccessConstants::AccessStatus::REVOKED)
      expect(access.revoked_at).to be_present
    end
  end
end
