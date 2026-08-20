require "rails_helper"

RSpec.describe "V1 Payment Transactions API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "transactions", :read)
  end

  describe "GET /v1/payment/transactions" do
    it "returns paginated transactions for the user" do
      create_list(:payment_transaction, 3, user: user, product: product)
      create(:payment_transaction, user: other_user, product: product)

      get "/v1/payment/transactions", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/payment/transactions/:id" do
    let(:transaction) { create(:payment_transaction, user: user, product: product) }

    it "returns transaction details" do
      get "/v1/payment/transactions/#{transaction.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("id" => transaction.id)
    end
  end

  describe "GET /v1/payment/transactions/recent" do
    it "returns successful recent transactions" do
      create(:payment_transaction, user: user, product: product, status: "succeeded")
      create(:payment_transaction, user: user, product: product, status: "canceled")

      get "/v1/payment/transactions/recent", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
    end
  end
end
