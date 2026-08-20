require "rails_helper"

RSpec.describe "V1 Payment Subscriptions API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:product) { create(:payment_product, name: "VIP Sub") }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    allow(NotificationService).to receive(:subscription_canceled)
    allow(NotificationService).to receive(:subscription_resumed)
    grant_permissions(user, "subscriptions", :read, :create, :delete)
  end

  describe "GET /v1/payment/subscriptions" do
    it "returns paginated subscriptions of the current user" do
      create_list(:payment_subscription, 3, user: user, product: product)
      create(:payment_subscription, user: other_user, product: product)

      get "/v1/payment/subscriptions", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/payment/subscriptions/:id" do
    let(:subscription) { create(:payment_subscription, user: user, product: product) }

    it "returns subscription details" do
      get "/v1/payment/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("id" => subscription.id)
    end
  end

  describe "POST /v1/payment/subscriptions/:id/cancel" do
    let(:subscription) do
      create(
        :payment_subscription,
        user: user,
        product: product,
        status: "active",
        cancel_at_period_end: false
      )
    end

    it "schedules cancellation and notifies" do
      allow(PaymentService::Client).to receive(:cancel_subscription)
        .with(subscription.stripe_subscription_id)
        .and_return(
          status: "active",
          cancel_at_period_end: true,
          cancel_at: 30.days.from_now,
          canceled_at: Time.current,
          ended_at: nil
        )

      post "/v1/payment/subscriptions/#{subscription.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      expect(subscription.reload.cancel_at_period_end).to be true
      expect(NotificationService).to have_received(:subscription_canceled)
    end

    it "rejects when already scheduled for cancellation" do
      subscription.update!(cancel_at_period_end: true)

      post "/v1/payment/subscriptions/#{subscription.id}/cancel", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /v1/payment/subscriptions/:id/resume" do
    let(:subscription) do
      create(
        :payment_subscription,
        user: user,
        product: product,
        status: "active",
        cancel_at_period_end: true,
        cancel_at: 30.days.from_now
      )
    end

    it "resumes cancellation and notifies" do
      allow(PaymentService::Client).to receive(:resume_subscription)
        .with(subscription.stripe_subscription_id)
        .and_return(
          status: "active",
          cancel_at_period_end: false,
          cancel_at: nil,
          canceled_at: nil,
          ended_at: nil
        )

      post "/v1/payment/subscriptions/#{subscription.id}/resume", headers: headers

      expect(response).to have_http_status(:ok)
      expect(subscription.reload.cancel_at_period_end).to be false
      expect(NotificationService).to have_received(:subscription_resumed)
    end

    it "rejects when not scheduled for cancellation" do
      subscription.update!(cancel_at_period_end: false)

      post "/v1/payment/subscriptions/#{subscription.id}/resume", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /v1/payment/subscriptions/:id" do
    it "discards an ended subscription" do
      subscription = create(
        :payment_subscription,
        user: user,
        product: product,
        status: "canceled",
        ended_at: 1.day.ago
      )

      delete "/v1/payment/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(subscription.reload.discarded_at).to be_present
    end

    it "rejects deleting an active subscription" do
      subscription = create(
        :payment_subscription,
        user: user,
        product: product,
        status: "active",
        ended_at: nil
      )

      delete "/v1/payment/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
