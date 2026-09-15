# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1 Admin User Notifications API", type: :request do
  let(:admin) { create(:user) }
  let(:regular_user) { create(:user) }
  let(:target_user) { create(:user, email: "target@example.com", username: "targetuser") }
  let(:token) { jwt_for(admin) }
  let(:user_token) { jwt_for(regular_user) }
  let(:headers) { authorization_headers(token) }
  let(:user_headers) { authorization_headers(user_token) }

  before do
    allow(CacheService).to receive(:write)
    allow(CacheService).to receive(:read).with("active_session:user:#{admin.id}:web").and_return(token)
    allow(CacheService).to receive(:read).with("active_session:user:#{regular_user.id}:web").and_return(user_token)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "user_notifications", :read, :delete)
  end

  describe "GET /v1/admin/user_notifications" do
    let!(:notif1) { create(:user_notification, user: target_user, title: "Special Alert", message: "Important details", clients: %w[web mobile]) }
    let!(:notif2) { create(:user_notification, :read, user: target_user, title: "Welcome Guide", clients: %w[web]) }
    let!(:discarded_notif) do
      n = create(:user_notification, user: target_user, title: "Archived Notice")
      n.discard!
      n
    end

    it "lists active user notifications by default" do
      get "/v1/admin/user_notifications", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.notifications_fetched"))
      expect(response_data.size).to eq(2)
      titles = response_data.map { |item| item.dig("attributes", "title") }
      expect(titles).to include("Special Alert", "Welcome Guide")
      expect(titles).not_to include("Archived Notice")
    end

    it "lists discarded notifications when view=discarded" do
      get "/v1/admin/user_notifications?view=discarded", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Archived Notice")
    end

    it "filters notifications by search query matching title, message, or user email" do
      get "/v1/admin/user_notifications?search=Special", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Special Alert")
    end

    it "filters notifications by read status" do
      get "/v1/admin/user_notifications?status=read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Welcome Guide")
    end

    it "filters notifications by client platform" do
      get "/v1/admin/user_notifications?client=mobile", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Special Alert")
    end

    it "forbids non-admin users" do
      get "/v1/admin/user_notifications", headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /v1/admin/user_notifications/:id" do
    let(:notif) { create(:user_notification, user: target_user, title: "Detail Test", metadata: { "order_id" => "123" }) }

    it "returns single user notification with user details and metadata" do
      get "/v1/admin/user_notifications/#{notif.id}", headers: headers

      expect(response).to have_http_status(:ok)
      attrs = response_data["attributes"]
      expect(attrs["title"]).to eq("Detail Test")
      expect(attrs["user_email"]).to eq("target@example.com")
      expect(attrs["metadata"]).to eq({ "order_id" => "123" })
    end
  end

  describe "POST /v1/admin/user_notifications/:id/discard" do
    let(:notif) { create(:user_notification, user: target_user) }

    it "soft-deletes notification to recycle bin" do
      post "/v1/admin/user_notifications/#{notif.id}/discard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.notification_discarded"))
      expect(notif.reload.discarded?).to be true
    end
  end

  describe "POST /v1/admin/user_notifications/:id/undiscard" do
    let(:notif) do
      n = create(:user_notification, user: target_user)
      n.discard!
      n
    end

    it "restores notification from recycle bin" do
      post "/v1/admin/user_notifications/#{notif.id}/undiscard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.notification_undiscarded"))
      expect(notif.reload.undiscarded?).to be true
    end
  end

  describe "DELETE /v1/admin/user_notifications/:id" do
    let(:notif) do
      n = create(:user_notification, user: target_user)
      n.discard!
      n
    end

    it "permanently destroys notification" do
      delete "/v1/admin/user_notifications/#{notif.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.notification_deleted"))
      expect(UserNotification.with_discarded.find_by(id: notif.id)).to be_nil
    end
  end

  describe "DELETE /v1/admin/user_notifications/bin" do
    before do
      2.times do
        n = create(:user_notification, user: target_user)
        n.discard!
      end
      create(:user_notification, user: target_user) # kept
    end

    it "empties the recycle bin" do
      delete "/v1/admin/user_notifications/bin", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.recycle_bin_emptied"))
      expect(UserNotification.with_discarded.discarded.count).to eq(0)
      expect(UserNotification.kept.count).to eq(1)
    end
  end

  describe "Batch Actions" do
    let!(:notif1) { create(:user_notification, user: target_user) }
    let!(:notif2) { create(:user_notification, user: target_user) }

    it "discards batch" do
      post "/v1/admin/user_notifications/discard_batch", params: { ids: [ notif1.id, notif2.id ] }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.batch_discarded"))
      expect(notif1.reload.discarded?).to be true
      expect(notif2.reload.discarded?).to be true
    end

    it "undiscards batch" do
      notif1.discard!
      notif2.discard!

      post "/v1/admin/user_notifications/undiscard_batch", params: { ids: [ notif1.id, notif2.id ] }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.batch_restored"))
      expect(notif1.reload.undiscarded?).to be true
      expect(notif2.reload.undiscarded?).to be true
    end

    it "destroys batch" do
      notif1.discard!
      notif2.discard!

      post "/v1/admin/user_notifications/destroy_batch", params: { ids: [ notif1.id, notif2.id ] }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("notification.batch_deleted"))
      expect(UserNotification.with_discarded.where(id: [ notif1.id, notif2.id ])).to be_empty
    end

    it "returns 422 if no ids selected" do
      post "/v1/admin/user_notifications/discard_batch", params: { ids: [] }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
