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

    it "filters products by search term matching name or description" do
      create(:payment_product, name: "Premium Membership", description: "All features", active: true)
      create(:payment_product, name: "Basic Starter", description: "Limited features", active: true)

      get "/v1/payment/products", params: { search: "Premium" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "name")).to eq("Premium Membership")
    end

    it "filters products by recurring boolean flag" do
      create(:payment_product, name: "Monthly Subscription", interval: :month, active: true)
      create(:payment_product, name: "Lifetime Pass", interval: nil, active: true)

      get "/v1/payment/products", params: { recurring: "true" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "name")).to eq("Monthly Subscription")
    end
  end

  describe "GET /v1/payment/products/:id" do
    let(:product) { create(:payment_product, name: "Pro Plan") }

    it "returns the product details" do
      get "/v1/payment/products/#{product.id}", headers: headers

      expect(response_data["id"]).to eq(product.id)
      expect(response_data.dig("attributes", "name")).to eq("Pro Plan")
    end
  end
end
