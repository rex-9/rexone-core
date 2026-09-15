require "rails_helper"

RSpec.describe "V1 Admin Chat Rooms API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, IamConstants::Resource::CHAT_ROOMS, :read, :update, :delete)
  end

  describe "GET /v1/admin/chat/rooms" do
    it "returns paginated rooms across all users" do
      user1 = create(:user)
      user2 = create(:user)
      create(:chat_room, user: user1)
      create(:chat_room, user: user2)

      get "/v1/admin/chat/rooms", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(2)
    end

    it "filters rooms by user_id" do
      user1 = create(:user)
      user2 = create(:user)
      create(:chat_room, user: user1)
      create(:chat_room, user: user2)

      get "/v1/admin/chat/rooms", params: { user_id: user1.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
    end
  end

  describe "GET /v1/admin/chat/rooms/:id" do
    it "returns room details" do
      room = create(:chat_room, title: "Inspection Room")

      get "/v1/admin/chat/rooms/#{room.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("Inspection Room")
    end
  end

  describe "PATCH /v1/admin/chat/rooms/:id" do
    it "updates room title and discarded state" do
      room = create(:chat_room, title: "Before Admin Edit")

      patch "/v1/admin/chat/rooms/#{room.id}",
            params: { room: { title: "After Admin Edit" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("After Admin Edit")
      expect(room.reload.title).to eq("After Admin Edit")
    end
  end

  describe "POST /v1/admin/chat/rooms/:id/discard" do
    it "discards the room" do
      room = create(:chat_room)

      post "/v1/admin/chat/rooms/#{room.id}/discard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(room.reload.discarded?).to be true
    end
  end

  describe "POST /v1/admin/chat/rooms/:id/undiscard" do
    it "restores the discarded room" do
      room = create(:chat_room, discarded_at: Time.current)

      post "/v1/admin/chat/rooms/#{room.id}/undiscard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(room.reload.discarded?).to be false
    end
  end

  describe "DELETE /v1/admin/chat/rooms/:id" do
    it "permanently destroys the room" do
      room = create(:chat_room)

      delete "/v1/admin/chat/rooms/#{room.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect { room.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
