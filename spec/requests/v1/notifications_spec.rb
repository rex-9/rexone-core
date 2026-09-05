require "rails_helper"

RSpec.describe "V1 Notifications API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "notifications", :read, :update, :delete)
  end

  describe "GET /v1/notifications" do
    it "requires authentication" do
      get "/v1/notifications"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns paginated notifications belonging to the current user" do
      3.times { create(:user_notification, user: user) }
      create(:user_notification, user: other_user)

      get "/v1/notifications", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.length).to eq(3)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters unread notifications" do
      create(:user_notification, :unread, user: user, title: "Unread 1")
      create(:user_notification, :read, user: user, title: "Read 1")

      get "/v1/notifications", params: { filter: "unread" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.length).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Unread 1")
    end

    it "filters read notifications" do
      create(:user_notification, :unread, user: user, title: "Unread 1")
      create(:user_notification, :read, user: user, title: "Read 1")

      get "/v1/notifications", params: { filter: "read" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.length).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Read 1")
    end
  end

  describe "GET /v1/notifications/unread_count" do
    it "returns the total unread count" do
      create(:user_notification, :unread, user: user)
      create(:user_notification, :unread, user: user)
      create(:user_notification, :read, user: user)
      create(:user_notification, :unread, user: other_user)

      get "/v1/notifications/unread_count", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["unread_count"]).to eq(2)
    end
  end

  describe "PUT /v1/notifications/:id/read" do
    let(:notification) { create(:user_notification, :unread, user: user) }

    it "marks an unread notification as read" do
      put "/v1/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "read")).to be(true)
      expect(notification.reload.read?).to be(true)
    end

    it "cannot mark another user's notification as read" do
      other_notification = create(:user_notification, :unread, user: other_user)

      put "/v1/notifications/#{other_notification.id}/read", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /v1/notifications/read_all" do
    it "marks all unread notifications of the user as read and increments parent notification read_count" do
      parent = create(:notification, sent_count: 3, read_count: 0)
      create_list(:user_notification, 3, :unread, user: user, notification: parent)
      other_notification = create(:user_notification, :unread, user: other_user, notification: parent)

      expect {
        put "/v1/notifications/read_all", headers: headers
      }.to change { parent.reload.read_count }.by(3)

      expect(response).to have_http_status(:ok)
      expect(response_data["unread_count"]).to eq(0)
      expect(user.user_notifications.unread.count).to eq(0)
      expect(other_notification.reload.read?).to be(false)
    end
  end

  describe "DELETE /v1/notifications/:id" do
    let(:notification) { create(:user_notification, user: user) }

    it "soft-deletes the notification" do
      delete "/v1/notifications/#{notification.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(notification.reload.discarded?).to be(true)
      expect(user.user_notifications.kept.count).to eq(0)
    end

    it "cannot delete another user's notification" do
      other_notification = create(:user_notification, user: other_user)

      delete "/v1/notifications/#{other_notification.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
