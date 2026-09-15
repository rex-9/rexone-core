require "rails_helper"

RSpec.describe "V1 Admin Chat Messages API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, IamConstants::Resource::CHAT_MESSAGES, :read, :update, :delete)
  end

  describe "GET /v1/admin/chat/messages" do
    it "returns messages across all rooms with pagination" do
      create_list(:chat_message, 4)

      get "/v1/admin/chat/messages", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(4)
    end

    it "filters messages by room_id and role" do
      room = create(:chat_room)
      create(:chat_message, room: room, role: "user")
      create(:chat_message, room: room, role: "assistant")

      get "/v1/admin/chat/messages", params: { room_id: room.id, role: "assistant" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "role")).to eq("assistant")
    end
  end

  describe "GET /v1/admin/chat/messages/:id" do
    it "returns message details" do
      message = create(:chat_message, content: "Admin inspected message")

      get "/v1/admin/chat/messages/#{message.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Admin inspected message")
    end
  end

  describe "PATCH /v1/admin/chat/messages/:id" do
    it "updates message content" do
      message = create(:chat_message, content: "Original content")

      patch "/v1/admin/chat/messages/#{message.id}",
            params: { message: { content: "Moderated content" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Moderated content")
      expect(message.reload.content).to eq("Moderated content")
    end
  end

  describe "POST /v1/admin/chat/messages/:id/discard" do
    it "discards the message" do
      message = create(:chat_message)

      post "/v1/admin/chat/messages/#{message.id}/discard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(message.reload.discarded?).to be true
    end
  end

  describe "POST /v1/admin/chat/messages/:id/undiscard" do
    it "restores the discarded message" do
      message = create(:chat_message, discarded_at: Time.current)

      post "/v1/admin/chat/messages/#{message.id}/undiscard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(message.reload.discarded?).to be false
    end
  end

  describe "DELETE /v1/admin/chat/messages/:id" do
    it "permanently destroys the message" do
      message = create(:chat_message)

      delete "/v1/admin/chat/messages/#{message.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect { message.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
