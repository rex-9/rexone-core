require "rails_helper"

RSpec.describe "V1 Chat Messages API", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:room) { create(:chat_room, user: user) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, IamConstants::Resource::CHAT_MESSAGES, :read, :create, :update, :delete)
    clear_enqueued_jobs
  end

  describe "GET /v1/chat/messages" do
    it "uses default room when room_id parameter is omitted" do
      get "/v1/chat/messages", headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "returns messages for given room" do
      create_list(:chat_message, 3, room: room)

      get "/v1/chat/messages", params: { room_id: room.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(3)
    end

    it "prevents accessing messages of another user's room" do
      other_user = create(:user)
      other_room = create(:chat_room, user: other_user)

      get "/v1/chat/messages", params: { room_id: other_room.id }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /v1/chat/messages" do
    it "queues an AI response when role is user and auto_respond is true" do
      expect {
        post "/v1/chat/messages",
             params: { message: "Hello AI", room_id: room.id },
             headers: headers
      }.to have_enqueued_job(Chat::ProcessMessageJob)

      expect(response).to have_http_status(:accepted)
      expect(response_data.dig("attributes", "content")).to eq("Hello AI")
      expect(response_meta["status"]).to eq("queued")
    end

    it "creates a message without queuing AI when ai is false" do
      chat_room = create(:chat_room, user: user)

      expect {
        post "/v1/chat/messages",
             params: { message: "Hello human", room_id: chat_room.id, ai: false },
             headers: headers
      }.not_to have_enqueued_job(Chat::ProcessMessageJob)

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "content")).to eq("Hello human")
    end

    it "returns unprocessable_entity when content is blank" do
      post "/v1/chat/messages",
           params: { message: "", room_id: room.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /v1/chat/messages/:id" do
    it "returns message details" do
      message = create(:chat_message, room: room, content: "Test message")

      get "/v1/chat/messages/#{message.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Test message")
    end
  end

  describe "PATCH /v1/chat/messages/:id" do
    it "updates the message content" do
      message = create(:chat_message, room: room, content: "Old message")

      patch "/v1/chat/messages/#{message.id}",
            params: { content: "Updated message" },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Updated message")
      expect(message.reload.content).to eq("Updated message")
    end
  end

  describe "DELETE /v1/chat/messages/:id" do
    it "discards the message" do
      message = create(:chat_message, room: room)

      delete "/v1/chat/messages/#{message.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Chat::Message.kept.where(id: message.id)).not_to exist
    end
  end

  describe "DELETE /v1/chat/messages/destroy_all" do
    it "clears all messages from the room" do
      create_list(:chat_message, 4, room: room)

      delete "/v1/chat/messages/destroy_all", params: { room_id: room.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(room.messages.count).to eq(0)
    end
  end
end
