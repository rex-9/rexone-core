require "rails_helper"

RSpec.describe "Admin payment coupons", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_permissions(admin, "payment_coupons", :read, :create, :update, :delete)
  end

  describe "GET /v1/admin/payment/coupons" do
    it "lists coupons with pagination" do
      coupon = create(:payment_coupon)

      get "/v1/admin/payment/coupons", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.first.dig("attributes", "id")).to eq(coupon.id)
    end

    it "filters discarded coupons" do
      kept_coupon = create(:payment_coupon)
      discarded_coupon = create(:payment_coupon)
      discarded_coupon.discard!

      get "/v1/admin/payment/coupons", params: { discarded: "true" }, headers: headers

      expect(response).to have_http_status(:ok)
      ids = response_data.map { |item| item.dig("attributes", "id") }
      expect(ids).to include(discarded_coupon.id)
      expect(ids).not_to include(kept_coupon.id)
    end
  end

  describe "POST /v1/admin/payment/coupons" do
    it "creates a new coupon" do
      allow(PaymentService::Client).to receive(:create_coupon) do |attrs|
        coupon = Payment::Coupon.create!(attrs)
        { data: coupon }
      end

      post "/v1/admin/payment/coupons",
           params: {
             coupon: {
               title: "Summer Promo",
               code: "SUMMER50",
               coupon_type: "percentage",
               amount: 50,
               currency: "usd",
               max_usage: 500
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["code"]).to eq("SUMMER50")
    end

    it "resolves target_user_emails to target_user_ids" do
      target_user = create(:user, email: "vip_customer@example.com")

      allow(PaymentService::Client).to receive(:create_coupon) do |attrs|
        coupon = Payment::Coupon.create!(attrs)
        { data: coupon }
      end

      post "/v1/admin/payment/coupons",
           params: {
             coupon: {
               title: "Targeted Customer Promo",
               code: "TARGETVIP",
               coupon_type: "percentage",
               amount: 25,
               currency: "usd",
               target_user_emails: [ "vip_customer@example.com" ]
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data["target_user_ids"]).to eq([ target_user.id ])
      expect(response_data["target_user_emails"]).to eq([ "vip_customer@example.com" ])
    end

    it "rejects non-existent target_user_emails with descriptive 422 error" do
      post "/v1/admin/payment/coupons",
           params: {
             coupon: {
               title: "Invalid Target Promo",
               code: "INVALIDTARGET",
               coupon_type: "percentage",
               amount: 25,
               currency: "usd",
               target_user_emails: [ "non_existent_user@example.com" ]
             }
           },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).dig("status", "error")).to include("non_existent_user@example.com")
    end
  end

  describe "POST /v1/admin/payment/coupons/batch" do
    it "creates batch coupons with generated codes" do
      allow(PaymentService::Client).to receive(:create_coupon) do |attrs|
        coupon = Payment::Coupon.create!(attrs)
        { data: coupon }
      end

      post "/v1/admin/payment/coupons/batch",
           params: {
             count: 5,
             prefix: "VIP",
             coupon: {
               title: "VIP Tier",
               coupon_type: "percentage",
               amount: 30,
               currency: "usd"
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.length).to eq(5)
      expect(response_data.first["code"]).to start_with("VIP")
    end
  end

  describe "PUT /v1/admin/payment/coupons/:id" do
    it "updates a coupon" do
      coupon = create(:payment_coupon, title: "Old Title")

      allow(PaymentService::Client).to receive(:update_coupon) do |id, attrs|
        c = Payment::Coupon.find(id)
        c.update!(attrs)
        { data: c }
      end

      put "/v1/admin/payment/coupons/#{coupon.id}",
          params: { coupon: { title: "New Title" } },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["title"]).to eq("New Title")
    end
  end

  describe "POST /v1/admin/payment/coupons/:id/discard" do
    it "discards a coupon" do
      coupon = create(:payment_coupon)

      allow(PaymentService::Client).to receive(:discard_coupon) do |id|
        c = Payment::Coupon.find(id)
        c.discard
        { data: c }
      end

      post "/v1/admin/payment/coupons/#{coupon.id}/discard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(coupon.reload).to be_discarded
    end
  end

  describe "GET /v1/admin/payment/coupons/:id/redemptions" do
    let(:coupon) { create(:payment_coupon) }
    let(:product) { create(:payment_product) }
    let(:customer) { create(:user) }

    it "lists redemptions for the coupon with pagination" do
      user_coupon = create(:payment_user_coupon, coupon: coupon, user: customer, product: product)

      get "/v1/admin/payment/coupons/#{coupon.id}/redemptions", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.first.dig("attributes", "id")).to eq(user_coupon.id)
      expect(response_data.first.dig("attributes", "coupon_id")).to eq(coupon.id)
    end

    it "searches redemptions by user email" do
      user1 = create(:user, email: "alpha@example.com")
      user2 = create(:user, email: "beta@example.com")
      redemption1 = create(:payment_user_coupon, coupon: coupon, user: user1, product: product)
      create(:payment_user_coupon, coupon: coupon, user: user2, product: product)

      get "/v1/admin/payment/coupons/#{coupon.id}/redemptions", params: { search: "alpha" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.length).to eq(1)
      expect(response_data.first.dig("attributes", "id")).to eq(redemption1.id)
    end

    it "sorts redemptions by user_email" do
      user_a = create(:user, email: "aaa@example.com")
      user_z = create(:user, email: "zzz@example.com")
      redemption_a = create(:payment_user_coupon, coupon: coupon, user: user_a, product: product)
      redemption_z = create(:payment_user_coupon, coupon: coupon, user: user_z, product: product)

      get "/v1/admin/payment/coupons/#{coupon.id}/redemptions",
          params: { sort_by: "user_email", sort_order: "asc" },
          headers: headers

      expect(response).to have_http_status(:ok)
      ids = response_data.map { |r| r.dig("attributes", "id") }
      expect(ids).to eq([redemption_a.id, redemption_z.id])
    end

    it "requires read permission on payment_coupons" do
      unauthorized_admin = create(:user, :admin)
      unauthorized_token = jwt_for(unauthorized_admin)
      unauthorized_headers = authorization_headers(unauthorized_token)
      allow(CacheService).to receive(:read).with(anything).and_return(unauthorized_token)

      get "/v1/admin/payment/coupons/#{coupon.id}/redemptions", headers: unauthorized_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /v1/admin/payment/coupons/:id" do
    it "shows an active coupon" do
      coupon = create(:payment_coupon)

      get "/v1/admin/payment/coupons/#{coupon.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["id"]).to eq(coupon.id)
    end

    it "shows a discarded coupon without raising 404" do
      coupon = create(:payment_coupon)
      coupon.discard!

      get "/v1/admin/payment/coupons/#{coupon.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["id"]).to eq(coupon.id)
      expect(response_data["discarded_at"]).to be_present
    end
  end

  describe "DELETE /v1/admin/payment/coupons/:id" do
    it "permanently deletes a coupon" do
      coupon = create(:payment_coupon)
      coupon.discard!

      delete "/v1/admin/payment/coupons/#{coupon.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Payment::Coupon.with_discarded.find_by(id: coupon.id)).to be_nil
    end
  end

  describe "DELETE /v1/admin/payment/coupons/bin" do
    it "empties the recycle bin" do
      coupon1 = create(:payment_coupon)
      coupon2 = create(:payment_coupon)
      kept_coupon = create(:payment_coupon)

      coupon1.discard!
      coupon2.discard!

      delete "/v1/admin/payment/coupons/bin", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Payment::Coupon.with_discarded.find_by(id: coupon1.id)).to be_nil
      expect(Payment::Coupon.with_discarded.find_by(id: coupon2.id)).to be_nil
      expect(Payment::Coupon.kept.find_by(id: kept_coupon.id)).to be_present
    end
  end

  describe "POST /v1/admin/payment/coupons/discard_batch" do
    it "discards selected coupons" do
      coupon1 = create(:payment_coupon)
      coupon2 = create(:payment_coupon)

      post "/v1/admin/payment/coupons/discard_batch",
           params: { ids: [coupon1.id, coupon2.id] },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(coupon1.reload).to be_discarded
      expect(coupon2.reload).to be_discarded
    end

    it "returns 422 if no ids are provided" do
      post "/v1/admin/payment/coupons/discard_batch",
           params: { ids: [] },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /v1/admin/payment/coupons/undiscard_batch" do
    it "restores selected coupons from recycle bin" do
      coupon1 = create(:payment_coupon)
      coupon2 = create(:payment_coupon)
      coupon1.discard!
      coupon2.discard!

      post "/v1/admin/payment/coupons/undiscard_batch",
           params: { ids: [coupon1.id, coupon2.id] },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(coupon1.reload).not_to be_discarded
      expect(coupon2.reload).not_to be_discarded
    end
  end

  describe "POST /v1/admin/payment/coupons/destroy_batch" do
    it "permanently deletes selected coupons" do
      coupon1 = create(:payment_coupon)
      coupon2 = create(:payment_coupon)
      coupon1.discard!
      coupon2.discard!

      post "/v1/admin/payment/coupons/destroy_batch",
           params: { ids: [coupon1.id, coupon2.id] },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Payment::Coupon.with_discarded.find_by(id: coupon1.id)).to be_nil
      expect(Payment::Coupon.with_discarded.find_by(id: coupon2.id)).to be_nil
    end
  end
end
