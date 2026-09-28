# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1 Admin Payment Products API", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:token) { jwt_for(admin_user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_permissions(admin_user, "payment_products", :read, :create, :update, :delete)
  end

  describe "GET /v1/admin/payment/products" do
    it "lists active products with pagination" do
      create_list(:payment_product, 3)

      get "/v1/admin/payment/products", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
    end

    it "lists discarded products when discarded=true" do
      product = create(:payment_product)
      product.discard!

      get "/v1/admin/payment/products?discarded=true", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first["id"]).to eq(product.id)
    end
  end

  describe "POST /v1/admin/payment/products" do
    it "creates a free product with nil provider and zero unit amount" do
      post "/v1/admin/payment/products",
           params: {
             product: {
               name: "Free Community Starter",
               description: "Always free plan",
               unit_amount: 0,
               currency: "usd",
               active: true
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["attributes"]).to include(
        "name" => "Free Community Starter",
        "free" => true,
        "stripe_product_id" => nil,
        "stripe_price_id" => nil,
        "google_play_product_id" => nil,
        "app_store_product_id" => nil
      )
      product = Payment::Product.find(response_data["id"])
      expect(product).to be_free
      expect(product.stripe_price_id).to be_nil
    end

    it "creates a Google Play in-app purchase product" do
      post "/v1/admin/payment/products",
           params: {
             product: {
               name: "Play Premium Tier",
               description: "Android exclusive in-app item",
               unit_amount: 1999,
               currency: "usd",
               google_play_product_id: "com.rexone.sub.monthly",
               interval: "month",
               active: true
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["attributes"]).to include(
        "name" => "Play Premium Tier",
        "google_play_product_id" => "com.rexone.sub.monthly"
      )
      product = Payment::Product.find(response_data["id"])
      expect(product.available_on_google_play?).to be(true)
      expect(product.in_app?).to be(true)
    end

    it "creates an App Store in-app purchase product" do
      post "/v1/admin/payment/products",
           params: {
             product: {
               name: "iOS VIP Pass",
               description: "Apple exclusive in-app consumable",
               unit_amount: 999,
               currency: "usd",
               app_store_product_id: "com.rexone.vip.onetime",
               active: true
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["attributes"]).to include(
        "name" => "iOS VIP Pass",
        "app_store_product_id" => "com.rexone.vip.onetime"
      )
      product = Payment::Product.find(response_data["id"])
      expect(product.available_on_app_store?).to be(true)
      expect(product.in_app?).to be(true)
    end

    it "creates an omnichannel product with both Google Play and App Store SKUs" do
      post "/v1/admin/payment/products",
           params: {
             product: {
               name: "Omnichannel Pro",
               description: "Cross-platform subscription",
               unit_amount: 999,
               currency: "usd",
               interval: "month",
               google_play_product_id: "com.rexone.pro.play",
               app_store_product_id: "com.rexone.pro.store",
               active: true
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["attributes"]).to include(
        "name" => "Omnichannel Pro",
        "google_play_product_id" => "com.rexone.pro.play",
        "app_store_product_id" => "com.rexone.pro.store"
      )
      product = Payment::Product.find(response_data["id"])
      expect(product.available_on_google_play?).to be(true)
      expect(product.available_on_app_store?).to be(true)
      expect(product.supported_providers).to include("google_play", "app_store")
    end
  end

  describe "PUT /v1/admin/payment/products/:id" do
    let(:free_product) { create(:payment_product, :free) }
    let(:play_product) { create(:payment_product, :google_play) }

    it "updates free product details without converting to premium" do
      put "/v1/admin/payment/products/#{free_product.id}",
          params: {
            product: {
              name: "Updated Free Name",
              description: "Updated description"
            }
          },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["attributes"]["name"]).to eq("Updated Free Name")
    end

    it "rejects converting a free product to premium" do
      put "/v1/admin/payment/products/#{free_product.id}",
          params: {
            product: {
              unit_amount: 1500
            }
          },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates an in-app product metadata directly" do
      put "/v1/admin/payment/products/#{play_product.id}",
          params: {
            product: {
              name: "Updated Play SKU",
              google_play_product_id: "com.rexone.play.v2"
            }
          },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["attributes"]["google_play_product_id"]).to eq("com.rexone.play.v2")
    end
  end

  describe "POST /v1/admin/payment/products/:id/discard and undiscard" do
    let(:free_product) { create(:payment_product, :free) }

    it "discards and restores a non-stripe product cleanly" do
      post "/v1/admin/payment/products/#{free_product.id}/discard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(free_product.reload).to be_discarded

      post "/v1/admin/payment/products/#{free_product.id}/undiscard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(free_product.reload).not_to be_discarded
    end
  end
end
