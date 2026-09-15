require "rails_helper"

RSpec.describe "V1 Chat Rooms API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, IamConstants::Resource::CHAT_ROOMS, :read, :create, :update, :delete)
  end

  describe "GET /v1/chat/rooms" do
    it "returns list of active chat rooms for current user" do
      create_list(:chat_room, 3, user: user)
      other_user = create(:user)
      create(:chat_room, user: other_user)

      get "/v1/chat/rooms", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "POST /v1/chat/rooms" do
    it "creates a new room with given title" do
      post "/v1/chat/rooms", params: { title: "Custom Title" }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "title")).to eq("Custom Title")
      expect(Chat::Room.where(user: user, title: "Custom Title")).to exist
    end

    it "creates a new room with default title when title is blank" do
      post "/v1/chat/rooms", params: { title: "" }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "title")).to be_present
    end
  end

  describe "GET /v1/chat/rooms/:id" do
    it "returns the room details if owned by user" do
      room = create(:chat_room, user: user, title: "My Room")

      get "/v1/chat/rooms/#{room.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("My Room")
    end

    it "returns 404 for rooms owned by another user" do
      other_user = create(:user)
      room = create(:chat_room, user: other_user)

      get "/v1/chat/rooms/#{room.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /v1/chat/rooms/:id" do
    it "updates the room title" do
      room = create(:chat_room, user: user, title: "Old Title")

      patch "/v1/chat/rooms/#{room.id}", params: { title: "New Title" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("New Title")
      expect(room.reload.title).to eq("New Title")
    end
  end

  describe "DELETE /v1/chat/rooms/:id" do
    it "discards/destroys the room" do
      room = create(:chat_room, user: user)

      delete "/v1/chat/rooms/#{room.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Chat::Room.kept.where(id: room.id)).not_to exist
    end
  end
end
