require "rails_helper"

RSpec.describe "V1 Accesses API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "accesses", :read, :delete)
  end

  describe "GET /v1/accesses" do
    it "returns paginated user accesses" do
      3.times { create(:access, user: user, product: create(:payment_product)) }
      create(:access, user: other_user, product: create(:payment_product))

      get "/v1/accesses", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/accesses/active" do
    it "returns only active accesses" do
      create(:access, user: user, product: create(:payment_product), status: AccessConstants::AccessStatus::ACTIVE)
      create(:access, user: user, product: create(:payment_product), status: AccessConstants::AccessStatus::REVOKED)

      get "/v1/accesses/active", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "status")).to eq(AccessConstants::AccessStatus::ACTIVE)
    end
  end

  describe "GET /v1/accesses/check" do
    it "checks if user has active access for a product" do
      create(:access, user: user, product: product, status: AccessConstants::AccessStatus::ACTIVE)

      get "/v1/accesses/check", params: { product_id: product.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("has_access" => true, "product_id" => product.id)
    end

    it "returns false when user does not have active access" do
      get "/v1/accesses/check", params: { product_id: product.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("has_access" => false, "product_id" => product.id)
    end
  end

  describe "DELETE /v1/accesses/:id" do
    let!(:access) { create(:access, user: user, product: product, status: AccessConstants::AccessStatus::ACTIVE) }

    it "revokes the user's access and records revoked_at timestamp" do
      delete "/v1/accesses/#{access.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(access.reload.status).to eq(AccessConstants::AccessStatus::REVOKED)
      expect(access.revoked_at).to be_present
    end

    it "rejects revoking access belonging to another user" do
      other_access = create(:access, user: other_user, product: product)

      delete "/v1/accesses/#{other_access.id}", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(other_access.reload.status).to eq(AccessConstants::AccessStatus::ACTIVE)
    end
  end
end
