require "rails_helper"

RSpec.describe "V1 Notifications API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  describe "GET /v1/notifications" do
    it "returns paginated notifications belonging to the current user" do
      3.times { create(:notification, user: user) }
      create(:notification, user: create(:user))

      get "/v1/notifications", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

  end

  describe "PUT /v1/notifications/:id/read" do
    it "marks the current user's notification as read" do
      notification = create(:notification, user: user, read_at: nil)

      put "/v1/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "read")).to be(true)
      expect(notification.reload.read_at).to be_present
    end

    it "returns 404 for another user's notification" do
      notification = create(:notification, user: create(:user))

      put "/v1/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /v1/notifications/read_all" do
    it "marks all unread notifications for the current user as read" do
      unread = create(:notification, user: user, read_at: nil)
      read = create(:notification, :read, user: user)
      other = create(:notification, user: create(:user), read_at: nil)

      put "/v1/notifications/read_all", headers: headers

      expect(response).to have_http_status(:ok)
      expect(unread.reload.read_at).to be_present
      expect(read.reload.read_at).to be_present
      expect(other.reload.read_at).to be_nil
    end
  end
end
