require "rails_helper"

RSpec.describe "V1 Payment Coupons API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product, unit_amount: 5_000, currency: "usd") }
  let!(:coupon) { create(:payment_coupon, code: "SAVE20", coupon_type: :percentage, amount: 20, currency: "usd") }

  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(CacheService).to receive(:read) { |k| k.to_s.start_with?("active_session:") ? token : memory_store.read(k) }
    allow(CacheService).to receive(:write) { |k, v, opts| memory_store.write(k, v, opts) }
    allow(CacheService).to receive(:delete) { |k| memory_store.delete(k) }
    allow(CacheService).to receive(:increment) do |k, amount, opts|
      val = (memory_store.read(k) || 0) + amount
      memory_store.write(k, val, opts)
      val
    end
    grant_permissions(user, "payment_coupons", :read)
  end

  describe "POST /v1/payment/coupons/validate" do
    it "validates an applicable coupon successfully" do
      post "/v1/payment/coupons/validate",
           params: { code: "SAVE20", product_id: product.id },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["valid"]).to be(true)
      expect(response_data["discount_amount"]).to eq(1_000)
      expect(response_data["final_amount"]).to eq(4_000)
      expect(response_data["coupon"]["code"]).to eq("SAVE20")
    end

    it "rejects an invalid coupon code and decrements remaining attempts" do
      post "/v1/payment/coupons/validate",
           params: { code: "INVALID", product_id: product.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(response_data["remaining_attempts"]).to eq(2)
      expect(response_data["cooldown_remaining"]).to eq(0)
    end

    it "triggers 30s cooldown and returns 429 on 3 consecutive failed attempts" do
      # Attempt 1
      post "/v1/payment/coupons/validate",
           params: { code: "BAD1", product_id: product.id },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response_data["remaining_attempts"]).to eq(2)

      # Attempt 2
      post "/v1/payment/coupons/validate",
           params: { code: "BAD2", product_id: product.id },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response_data["remaining_attempts"]).to eq(1)

      # Attempt 3 -> 429 Too Many Requests
      post "/v1/payment/coupons/validate",
           params: { code: "BAD3", product_id: product.id },
           headers: headers
      expect(response).to have_http_status(:too_many_requests)
      expect(response_status["success"]).to be(false)
      expect(response_data["remaining_attempts"]).to eq(0)
      expect(response_data["cooldown_remaining"]).to eq(30)

      # Attempt 4 while in cooldown -> blocked immediately
      post "/v1/payment/coupons/validate",
           params: { code: "SAVE20", product_id: product.id },
           headers: headers
      expect(response).to have_http_status(:too_many_requests)
      expect(response_data["remaining_attempts"]).to eq(0)
      expect(response_data["cooldown_remaining"]).to be > 0
    end
  end
end
