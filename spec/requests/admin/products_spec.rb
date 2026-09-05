require "rails_helper"

RSpec.describe "Admin payment products", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  it "lists products for admins with product read access" do
    grant_admin_product_permission(:read)
    create(:payment_product, name: "Starter")

    get "/v1/admin/payment/products", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.fetched"))
    expect(response_data).not_to be_empty
  end

  it "keeps discarded products out of the active list and returns them from the recycle bin" do
    grant_admin_product_permission(:read)
    active_product = create(:payment_product, name: "Active")
    discarded_product = create(:payment_product, name: "Discarded")
    discarded_product.discard!

    get "/v1/admin/payment/products", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |record| record.dig("attributes", "id") }).to include(active_product.id)
    expect(response_data.map { |record| record.dig("attributes", "id") }).not_to include(discarded_product.id)

    get "/v1/admin/payment/products/discarded", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.discarded_fetched"))
    expect(response_data.first.dig("attributes", "id")).to eq(discarded_product.id)
    expect(response_data.first.dig("attributes", "discarded_at")).to be_present
  end

  it "creates a Stripe-backed product with localized messages" do
    grant_admin_product_permission(:create)
    product = build(:payment_product, name: "Premium", price_unit_amount: 2_500)

    allow(PaymentService::Client).to receive(:create_product).and_return(data: product)

    post "/v1/admin/payment/products",
         params: { product: valid_product_params },
         headers: headers.merge("X-Locale" => "my"),
         as: :json

    expect(response).to have_http_status(:created)
    expect(response_status["message"]).to eq(I18n.t("payment.products.created", locale: :my))
    expect(response_data.fetch("name")).to eq("Premium")
    expect(PaymentService::Client).to have_received(:create_product).with(
      hash_including(name: "Premium", price_unit_amount: 2_500, currency: "usd", cycle: "month", active: true)
    )
  end

  it "creates a free product with localized messages" do
    grant_admin_product_permission(:create)
    product = build(:payment_product, name: "Free", price_unit_amount: 0, cycle: nil)

    allow(PaymentService::Client).to receive(:create_product).and_return(data: product)

    post "/v1/admin/payment/products",
         params: {
           product: valid_product_params.except(:cycle).merge(
             name: "Free",
             price_unit_amount: 0
           )
         },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response_data.fetch("free")).to eq(true)
    expect(response_data.fetch("price")).to eq("Free")
    expect(PaymentService::Client).to have_received(:create_product).with(
      hash_including(name: "Free", price_unit_amount: 0, currency: "usd", active: true)
    )
  end

  it "creates a one-time paid product without requiring cycle" do
    grant_admin_product_permission(:create)
    product = build(:payment_product, name: "One Time", price_unit_amount: 2_500, cycle: nil)

    allow(PaymentService::Client).to receive(:create_product).and_return(data: product)

    post "/v1/admin/payment/products",
         params: {
           product: valid_product_params.except(:cycle).merge(name: "One Time")
         },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(PaymentService::Client).to have_received(:create_product).with(
      hash_including(name: "One Time", price_unit_amount: 2_500, currency: "usd", active: true)
    )
  end

  it "updates a Stripe-backed product" do
    grant_admin_product_permission(:update)
    product = create(:payment_product)

    allow(PaymentService::Client).to receive(:update_product).and_return(data: product.tap { |record| record.name = "Updated" })

    patch "/v1/admin/payment/products/#{product.id}",
          params: { product: { name: "Updated" } },
          headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.updated"))
    expect(PaymentService::Client).to have_received(:update_product).with(product.id, hash_including(name: "Updated"))
  end

  it "discards a Stripe-backed product" do
    grant_admin_product_permission(:delete)
    product = create(:payment_product)

    allow(PaymentService::Client).to receive(:discard_product).and_return(data: product)

    post "/v1/admin/payment/products/#{product.id}/discard", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.discarded"))
    expect(PaymentService::Client).to have_received(:discard_product).with(product.id)
  end

  it "assigns a thumbnail to a product" do
    grant_admin_product_permission(:update)
    product = create(:payment_product)
    thumbnail_asset = create(:asset, type: AssetConstants::AssetType::THUMBNAIL, format: "image", assetable: nil)

    allow(PaymentService::Client).to receive(:update_product).and_return(data: product)

    patch "/v1/admin/payment/products/#{product.id}",
          params: { product: { thumbnail_asset_id: thumbnail_asset.id } },
          headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data["thumbnail_asset_id"]).to eq(thumbnail_asset.id)
    expect(response_data["thumbnail_url"]).to eq(thumbnail_asset.url)
    expect(thumbnail_asset.reload.assetable).to eq(product)
  end

  it "restores a discarded Stripe-backed product" do
    grant_admin_product_permission(:delete)
    product = create(:payment_product)
    product.discard!

    allow(PaymentService::Client).to receive(:undiscard_product).and_return(data: product.undiscard! && product)

    post "/v1/admin/payment/products/#{product.id}/undiscard", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.restored"))
    expect(PaymentService::Client).to have_received(:undiscard_product).with(product.id)
  end

  it "requires product permissions" do
    get "/v1/admin/payment/products", headers: headers

    expect(response).to have_http_status(:forbidden)
  end

  describe "GET /v1/admin/payment/products/:id" do
    let(:product) { create(:payment_product, name: "Starter") }

    it "shows a product" do
      grant_admin_product_permission(:read)
      get "/v1/admin/payment/products/#{product.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response_data).to include("name" => "Starter")
    end

    it "returns 404 for non-existent product" do
      grant_admin_product_permission(:read)
      get "/v1/admin/payment/products/nonexistent-uuid", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /v1/admin/payment/products error" do
    it "returns 422 when service error occurs" do
      grant_admin_product_permission(:create)
      allow(PaymentService::Client).to receive(:create_product).and_return(error: "Stripe error")

      post "/v1/admin/payment/products",
           params: { product: valid_product_params },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  def valid_product_params
    {
      name: "Premium",
      description: "Premium access",
      price_unit_amount: 2_500,
      currency: "usd",
      cycle: "month",
      active: true
    }
  end

  def grant_admin_product_permission(action)
    role = admin.roles.find_by!(name: "admin")
    permission = Iam::Permission.find_or_create_by!(action: action.to_s, resource: "products")

    Iam::RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end
