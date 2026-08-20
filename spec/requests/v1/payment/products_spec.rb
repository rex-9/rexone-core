require "rails_helper"

RSpec.describe "V1 Payment Products API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "products", :read)
  end

  describe "GET /v1/payment/products" do
    it "returns paginated active products" do
      create_list(:payment_product, 3, active: true)
      create(:payment_product, active: false)

      get "/v1/payment/products", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/payment/products/:id" do
    let(:product) { create(:payment_product, name: "Pro Plan") }

    it "returns the product details" do
      get "/v1/payment/products/#{product.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("name" => "Pro Plan")
    end
  end
end
