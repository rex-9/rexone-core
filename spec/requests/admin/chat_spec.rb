require "rails_helper"

RSpec.describe "Admin chat", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:room) { create(:chat_room, title: "Support chat") }
  let(:message) { create(:chat_message, room: room, content: "Hello") }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(admin)
  end

  it "lists and updates chat rooms with localized messages" do
    grant_admin_chat_permission(:read, "rooms")
    grant_admin_chat_permission(:update, "rooms")
    room

    get "/v1/admin/chat/rooms", headers: headers.merge("X-Locale" => "my")
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.rooms_retrieved", locale: :my))

    patch "/v1/admin/chat/rooms/#{room.id}",
          params: { room: { title: "Updated support chat" } },
          headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.room_updated", locale: :my))
    expect(response_data).to include("id" => room.id, "title" => "Updated support chat")
  end

  it "lists and updates chat messages with localized messages" do
    grant_admin_chat_permission(:read, "messages")
    grant_admin_chat_permission(:update, "messages")
    message

    get "/v1/admin/chat/messages", headers: headers.merge("X-Locale" => "my")
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.messages_retrieved", locale: :my))

    patch "/v1/admin/chat/messages/#{message.id}",
          params: { message: { content: "Updated message" } },
          headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.message_updated", locale: :my))
    expect(response_data).to include("id" => message.id, "content" => "Updated message")
  end

  it "discards, restores, and permanently deletes chat records through admin endpoints" do
    grant_admin_chat_permission(:delete, "messages")
    grant_admin_chat_permission(:delete, "rooms")
    message
    room

    # Discard message
    post "/v1/admin/chat/messages/#{message.id}/discard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(message.reload.discarded?).to be(true)

    # Active messages list should not include discarded message
    get "/v1/admin/chat/messages", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_data.map { |m| m["id"] }).not_to include(message.id)

    # Discarded messages list should include discarded message
    get "/v1/admin/chat/messages?discarded=true", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_data.map { |m| m["id"] }).to include(message.id)

    # Restore message
    post "/v1/admin/chat/messages/#{message.id}/undiscard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(message.reload.discarded?).to be(false)

    # Permanent destroy message
    delete "/v1/admin/chat/messages/#{message.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(Chat::Message.with_discarded.find_by(id: message.id)).to be_nil

    # Discard room
    post "/v1/admin/chat/rooms/#{room.id}/discard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(room.reload.discarded?).to be(true)

    # Discarded rooms list should include discarded room
    get "/v1/admin/chat/rooms?discarded=true", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_data.map { |r| r["id"] }).to include(room.id)

    # Restore room
    post "/v1/admin/chat/rooms/#{room.id}/undiscard", headers: headers
    expect(response).to have_http_status(:ok)
    expect(room.reload.discarded?).to be(false)

    # Permanent destroy room
    delete "/v1/admin/chat/rooms/#{room.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(Chat::Room.with_discarded.find_by(id: room.id)).to be_nil
  end

  describe "GET /v1/admin/chat/rooms/:id" do
    it "shows a chat room" do
      grant_admin_chat_permission(:read, "rooms")
      get "/v1/admin/chat/rooms/#{room.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response_data).to include("id" => room.id, "title" => "Support chat")
    end

    it "returns 404 for non-existent room" do
      grant_admin_chat_permission(:read, "rooms")
      get "/v1/admin/chat/rooms/nonexistent-uuid", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /v1/admin/chat/messages/:id" do
    it "shows a chat message" do
      grant_admin_chat_permission(:read, "messages")
      get "/v1/admin/chat/messages/#{message.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response_data).to include("id" => message.id, "content" => "Hello")
    end

    it "returns 404 for non-existent message" do
      grant_admin_chat_permission(:read, "messages")
      get "/v1/admin/chat/messages/nonexistent-uuid", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  def grant_admin_chat_permission(action, resource)
    grant_super_admin_role(admin)
  end
end
