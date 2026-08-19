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
  end

  it "deletes chat records through admin endpoints" do
    grant_admin_chat_permission(:delete, "messages")
    grant_admin_chat_permission(:delete, "rooms")
    message

    delete "/v1/admin/chat/messages/#{message.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.message_deleted"))

    delete "/v1/admin/chat/rooms/#{room.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response_status["message"]).to eq(I18n.t("admin.chat.room_deleted"))
  end

  def grant_admin_chat_permission(action, resource)
    role = admin.roles.find_by!(name: "admin")
    permission = Iam::Permission.find_or_create_by!(action: action.to_s, resource: resource)

    Iam::RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end
