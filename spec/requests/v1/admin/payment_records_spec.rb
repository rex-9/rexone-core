require "rails_helper"

RSpec.describe "Admin payment records", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  describe "purchases" do
    before { grant_admin_permissions(admin, "purchases", :read) }

    it "lists purchases across users and exposes admin display fields" do
      purchase = create(:payment_purchase)

      get "/v1/admin/payment/purchases", headers: headers

      expect(response).to have_http_status(:ok)
      attributes = response_data.first.fetch("attributes")
      expect(attributes.fetch("id")).to eq(purchase.id)
      expect(attributes.fetch("user_email")).to eq(purchase.user.email)
      expect(attributes.fetch("product_name")).to eq(purchase.product.name)
    end

    it "shows a purchase" do
      purchase = create(:payment_purchase)

      get "/v1/admin/payment/purchases/#{purchase.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "id")).to eq(purchase.id)
    end
  end

  describe "subscriptions" do
    before { grant_admin_permissions(admin, "subscriptions", :read) }

    it "filters subscriptions by status and interval" do
      expected = create(:payment_subscription, status: "active", interval: "month")
      create(:payment_subscription, status: "canceled", interval: "year")

      get "/v1/admin/payment/subscriptions",
          params: { status: "active", interval: "month" },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |item| item.dig("attributes", "id") }).to eq([ expected.id ])
    end

    it "shows a subscription" do
      subscription = create(:payment_subscription)

      get "/v1/admin/payment/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "id")).to eq(subscription.id)
    end
  end

  it "requires matching admin read permission" do
    get "/v1/admin/payment/purchases", headers: headers
    expect(response).to have_http_status(:forbidden)

    get "/v1/admin/payment/subscriptions", headers: headers
    expect(response).to have_http_status(:forbidden)
  end
end
