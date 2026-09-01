require "rails_helper"

RSpec.describe "V1 Payments API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product, cycle: nil) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "payments", :create, :read)
  end

  describe "POST /v1/payment/session" do
    it "creates a checkout session successfully" do
      allow(PaymentService::Client).to receive(:create_checkout_session)
        .with(
          user_id: user.id,
          product_id: product.id,
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel"
        )
        .and_return(checkout_url: "https://stripe.com/pay", session_id: "cs_test_123")

      post "/v1/payment/session",
           params: {
             product_id: product.id,
             success_url: "https://example.com/success",
             cancel_url: "https://example.com/cancel"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "checkout_url" => "https://stripe.com/pay",
        "session_id" => "cs_test_123"
      )
    end

    it "rejects when active subscription already exists for recurring product" do
      recurring_product = create(:payment_product, cycle: "month")
      create(:payment_subscription, user: user, product: recurring_product, status: "active")

      post "/v1/payment/session",
           params: { product_id: recurring_product.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "grants access directly for free products without creating a Stripe checkout session" do
      free_product = create(:payment_product, price_unit_amount: 0, cycle: nil)
      expect(PaymentService::Client).not_to receive(:create_checkout_session)

      post "/v1/payment/session",
           params: { product_id: free_product.id },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "free_access_granted" => true,
        "product_id" => free_product.id
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: free_product.id)).to be(true)
    end

    it "rejects free product checkout when active access already exists" do
      free_product = create(:payment_product, price_unit_amount: 0, cycle: nil)
      AccessService.grant(user_id: user.id, product_id: free_product.id)

      post "/v1/payment/session",
           params: { product_id: free_product.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /v1/payment/session/:session_id" do
    it "returns session status from payment client" do
      allow(PaymentService::Client).to receive(:get_session)
        .with("cs_test_123")
        .and_return(status: "complete", payment_status: "paid")

      get "/v1/payment/session/cs_test_123", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("status" => "complete", "payment_status" => "paid")
    end

    it "returns 404 when session is not found" do
      allow(PaymentService::Client).to receive(:get_session)
        .with("cs_unknown")
        .and_return(error: "Session not found")

      get "/v1/payment/session/cs_unknown", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
