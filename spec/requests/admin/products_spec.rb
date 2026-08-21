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

  it "creates a Stripe-backed product with localized messages" do
    grant_admin_product_permission(:create)
    product = build(:payment_product, name: "Premium", price_unit_amount: 2_500)

    allow(PaymentService::Client).to receive(:create_product).and_return(product)

    post "/v1/admin/payment/products",
         params: { product: valid_product_params },
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:created)
    expect(response_status["message"]).to eq(I18n.t("payment.products.created", locale: :my))
    expect(response_data.dig("product", "name")).to eq("Premium")
    expect(PaymentService::Client).to have_received(:create_product).with(
      hash_including(name: "Premium", price_unit_amount: 2_500, currency: "usd", cycle: "month", active: true)
    )
  end

  it "creates a free product with localized messages" do
    grant_admin_product_permission(:create)
    product = build(:payment_product, name: "Free", price_unit_amount: 0, cycle: nil)

    allow(PaymentService::Client).to receive(:create_product).and_return(product)

    post "/v1/admin/payment/products",
         params: {
           product: valid_product_params.merge(
             name: "Free",
             price_unit_amount: 0,
             cycle: ""
           )
         },
         headers: headers

    expect(response).to have_http_status(:created)
    expect(response_data.dig("product", "free")).to eq(true)
    expect(response_data.dig("product", "price")).to eq("Free")
    expect(PaymentService::Client).to have_received(:create_product).with(
      hash_including(name: "Free", price_unit_amount: 0, currency: "usd", cycle: nil, active: true)
    )
  end

  it "updates a Stripe-backed product" do
    grant_admin_product_permission(:update)
    product = create(:payment_product)

    allow(PaymentService::Client).to receive(:update_product).and_return(product.tap { |record| record.name = "Updated" })

    patch "/v1/admin/payment/products/#{product.id}",
          params: { product: { name: "Updated" } },
          headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.updated"))
    expect(PaymentService::Client).to have_received(:update_product).with(product.id, hash_including(name: "Updated"))
  end

  it "archives a Stripe-backed product instead of hard deleting it" do
    grant_admin_product_permission(:delete)
    product = create(:payment_product)

    allow(PaymentService::Client).to receive(:archive_product).and_return(product)

    delete "/v1/admin/payment/products/#{product.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("payment.products.deleted"))
    expect(PaymentService::Client).to have_received(:archive_product).with(product.id)
  end

  it "requires product permissions" do
    get "/v1/admin/payment/products", headers: headers

    expect(response).to have_http_status(:forbidden)
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
