require "rails_helper"

RSpec.describe "V1 Payment Purchases API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "purchases", :read)
  end

  describe "GET /v1/payment/purchases" do
    it "returns paginated purchases for the user" do
      create_list(:payment_purchase, 3, user: user, product: product)
      create(:payment_purchase, user: other_user, product: product)

      get "/v1/payment/purchases", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/payment/purchases/:id" do
    let(:purchase) { create(:payment_purchase, user: user, product: product) }

    it "returns purchase details" do
      get "/v1/payment/purchases/#{purchase.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("id" => purchase.id)
    end
  end

  describe "GET /v1/payment/purchases/recent" do
    it "returns successful recent purchases" do
      create(:payment_purchase, user: user, product: product, status: "succeeded")
      create(:payment_purchase, user: user, product: product, status: "canceled")

      get "/v1/payment/purchases/recent", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
    end
  end
end
