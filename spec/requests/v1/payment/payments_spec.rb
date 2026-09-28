require "rails_helper"

RSpec.describe "V1 Payments API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product, interval: nil) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "payments", :create, :read)
  end

  describe "POST /v1/payment/session" do
    it "creates a checkout session successfully" do
      allow(Payment::Providers::Client).to receive(:create_checkout_session)
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
      recurring_product = create(:payment_product, interval: "month")
      create(:payment_subscription, user: user, product: recurring_product, status: "active")

      post "/v1/payment/session",
           params: { product_id: recurring_product.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "grants access directly for free products without creating a Stripe checkout session" do
      free_product = create(:payment_product, unit_amount: 0, interval: nil)
      expect(Payment::Providers::Client).not_to receive(:create_checkout_session)

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
      free_product = create(:payment_product, unit_amount: 0, interval: nil)
      AccessService.grant(user_id: user.id, product_id: free_product.id)

      post "/v1/payment/session",
           params: { product_id: free_product.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a checkout session with valid coupon" do
      coupon = create(:payment_coupon, coupon_type: :percentage, amount: 20, code: "SAVE20")
      allow(Payment::Providers::Client).to receive(:create_checkout_session)
        .with(
          user_id: user.id,
          product_id: product.id,
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel",
          coupon: coupon
        )
        .and_return(checkout_url: "https://stripe.com/pay", session_id: "cs_test_coupon")

      post "/v1/payment/session",
           params: {
             product_id: product.id,
             success_url: "https://example.com/success",
             cancel_url: "https://example.com/cancel",
             coupon_code: "SAVE20"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["session_id"]).to eq("cs_test_coupon")
    end

    it "grants access directly when coupon provides 100% discount" do
      free_coupon = create(:payment_coupon, coupon_type: :percentage, amount: 100, code: "FREE100")
      expect(Payment::Providers::Client).not_to receive(:create_checkout_session)

      post "/v1/payment/session",
           params: {
             product_id: product.id,
             coupon_code: "free100"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "free_access_granted" => true,
        "product_id" => product.id,
        "coupon_code" => "FREE100"
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: product.id)).to be(true)
      expect(Payment::UserCoupon.where(coupon: free_coupon, user: user, product: product)).to exist
    end

    it "routes to Stripe Checkout when 100% discount coupon is applied to recurring product" do
      recurring_product = create(:payment_product, interval: :month)
      free_coupon = create(:payment_coupon, coupon_type: :percentage, amount: 100, code: "FREE100")

      allow(Payment::Providers::Client).to receive(:create_checkout_session)
        .with(
          user_id: user.id,
          product_id: recurring_product.id,
          success_url: nil,
          cancel_url: nil,
          coupon: free_coupon
        )
        .and_return(checkout_url: "https://stripe.com/pay_sub", session_id: "cs_test_sub_100")

      post "/v1/payment/session",
           params: {
             product_id: recurring_product.id,
             coupon_code: "free100"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["session_id"]).to eq("cs_test_sub_100")
      expect(response_data["checkout_url"]).to eq("https://stripe.com/pay_sub")
    end

    it "rejects checkout when coupon code is invalid" do
      post "/v1/payment/session",
           params: {
             product_id: product.id,
             coupon_code: "NONEXISTENT"
           },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /v1/payment/session/:session_id" do
    it "returns session status from payment client" do
      allow(Payment::Providers::Client).to receive(:get_session)
        .with("cs_test_123")
        .and_return(status: "complete", payment_status: "paid")

      get "/v1/payment/session/cs_test_123", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("status" => "complete", "payment_status" => "paid")
    end

    it "returns 404 when session is not found" do
      allow(Payment::Providers::Client).to receive(:get_session)
        .with("cs_unknown")
        .and_return(error: "Session not found")

      get "/v1/payment/session/cs_unknown", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /v1/payment/verify" do
    let(:play_product) { create(:payment_product, :google_play, interval: nil) }
    let(:store_product) { create(:payment_product, :app_store, interval: "month") }

    it "verifies and provisions Google Play one-time purchase" do
      post "/v1/payment/verify",
           params: {
             product_id: play_product.id,
             provider: PaymentConstants::Provider::GOOGLE_PLAY,
             purchase_token: "token_play_123",
             package_name: "com.rexone.app"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(MessageService::Payment.t(MessageService::Payment::VERIFIED_AND_GRANTED))
      expect(response_data).to include(
        "verified" => true,
        "product_id" => play_product.id,
        "provider" => PaymentConstants::Provider::GOOGLE_PLAY
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: play_product.id)).to be(true)
      purchase = Payment::Purchase.find_by(provider: PaymentConstants::Provider::GOOGLE_PLAY, user: user)
      expect(purchase).to be_present
      expect(purchase.succeeded?).to be(true)
    end

    it "verifies and provisions App Store subscription" do
      post "/v1/payment/verify",
           params: {
             product_id: store_product.id,
             provider: PaymentConstants::Provider::APP_STORE,
             transaction_id: "tx_store_999",
             receipt_data: "jws_token_here"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "verified" => true,
        "product_id" => store_product.id,
        "provider" => PaymentConstants::Provider::APP_STORE
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: store_product.id)).to be(true)
      subscription = Payment::Subscription.find_by(provider: PaymentConstants::Provider::APP_STORE, user: user)
      expect(subscription).to be_present
      expect(subscription.active?).to be(true)
    end

    it "verifies Google Play purchase with a valid coupon and records redemption" do
      coupon = create(:payment_coupon, coupon_type: :percentage, amount: 25, code: "PLAY25")

      post "/v1/payment/verify",
           params: {
             product_id: play_product.id,
             provider: PaymentConstants::Provider::GOOGLE_PLAY,
             transaction_id: "GPA.1234-5678-9012",
             purchase_token: "play_token_with_coupon",
             package_name: "com.rexone.app",
             coupon_code: "PLAY25"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "verified" => true,
        "product_id" => play_product.id,
        "provider" => PaymentConstants::Provider::GOOGLE_PLAY,
        "coupon_code" => "PLAY25",
        "discount_amount" => 250,
        "final_amount" => 750
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: play_product.id)).to be(true)

      purchase = Payment::Purchase.find_by(provider: PaymentConstants::Provider::GOOGLE_PLAY, user: user)
      expect(purchase).to be_present
      expect(purchase.user_coupon).to be_present
      expect(purchase.user_coupon.coupon_id).to eq(coupon.id)
      expect(purchase.user_coupon.discount_amount).to eq(250)
      expect(coupon.reload.used_count).to eq(1)
    end

    it "rejects Google Play verification when coupon is invalid or expired" do
      coupon = create(:payment_coupon, code: "EXPIRED50", expires_at: 1.day.ago)

      post "/v1/payment/verify",
           params: {
             product_id: play_product.id,
             provider: PaymentConstants::Provider::GOOGLE_PLAY,
             transaction_id: "GPA.9999-8888-7777",
             purchase_token: "play_token_expired_coupon",
             coupon_code: "EXPIRED50"
           },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to be_present
      expect(AccessService.has_access?(user_id: user.id, product_id: play_product.id)).to be(false)
      expect(Payment::Purchase.find_by(provider_payment_id: "GPA.9999-8888-7777")).to be_nil
    end

    it "verifies App Store subscription with a valid coupon and records redemption" do
      coupon = create(:payment_coupon, coupon_type: :fixed, amount: 500, code: "APPLE5OFF")

      post "/v1/payment/verify",
           params: {
             product_id: store_product.id,
             provider: PaymentConstants::Provider::APP_STORE,
             transaction_id: "tx_store_with_coupon",
             receipt_data: "jws_token_with_coupon",
             coupon_code: "APPLE5OFF"
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "verified" => true,
        "product_id" => store_product.id,
        "provider" => PaymentConstants::Provider::APP_STORE,
        "coupon_code" => "APPLE5OFF",
        "discount_amount" => 500,
        "final_amount" => 500
      )
      expect(AccessService.has_access?(user_id: user.id, product_id: store_product.id)).to be(true)

      subscription = Payment::Subscription.find_by(provider: PaymentConstants::Provider::APP_STORE, user: user)
      expect(subscription).to be_present
      expect(subscription.user_coupon).to be_present
      expect(subscription.user_coupon.coupon_id).to eq(coupon.id)
      expect(subscription.user_coupon.discount_amount).to eq(500)
      expect(coupon.reload.used_count).to eq(1)
    end

    it "returns 422 unprocessable content when verification fails" do
      allow(Payment::IapService).to receive(:verify_and_provision)
        .and_return(error: "Invalid receipt token")

      post "/v1/payment/verify",
           params: {
             product_id: play_product.id,
             provider: PaymentConstants::Provider::GOOGLE_PLAY,
             purchase_token: "invalid_token"
           },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to eq("Invalid receipt token")
      expect(response_status["message"]).to eq(MessageService::Payment.t(MessageService::Payment::VERIFICATION_FAILED))
    end
  end
end
