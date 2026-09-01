require "rails_helper"

RSpec.describe "Queued AI chat", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:room) { create(:chat_room, user: user) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_ai_permissions(user)
  end

  it "persists and queues a message without waiting for the provider" do
    expect do
      post "/v1/ai/chat",
           params: { room_id: room.id, message: "Hello", temperature: 0.3, max_tokens: 250 },
           headers: headers.merge("X-Locale" => "my")
    end.to change(room.messages, :count).by(1)
      .and have_enqueued_job(Ai::ProcessChatJob)

    message = room.messages.last
    expect(response).to have_http_status(:ok)
    expect(response_data).to include("room_id" => room.id, "status" => "queued")
    expect(message).to have_attributes(role: "user", content: "Hello")
    expect(message.metadata).to include(
      "status" => "queued",
      "temperature" => 0.3,
      "max_tokens" => 250
    )
  end

  it "rejects another message while the room is processing" do
    create(:chat_message, room: room, metadata: { status: "processing" })

    expect do
      post "/v1/ai/chat", params: { room_id: room.id, message: "Again" }, headers: headers
    end.not_to change(room.messages, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_data).to include("processing" => true, "room_id" => room.id)
  end

  it "rolls persistence back when the AI job cannot be queued" do
    allow(Ai::ProcessChatJob).to receive(:perform_later)
      .and_raise(SolidQueue::Job::EnqueueError.new("queue unavailable"))

    expect do
      post "/v1/ai/chat", params: { room_id: room.id, message: "Hello" }, headers: headers
    end.not_to change(room.messages, :count)

    expect(response).to have_http_status(:service_unavailable)
  end

  it "returns durable processing state with room history" do
    create(:chat_message, room: room, metadata: { status: "retrying" })

    get "/v1/ai/history", params: { room_id: room.id }, headers: headers

    expect(response).to have_http_status(:ok)
    message = response_data.first
    expect(message.dig("attributes", "room_id")).to eq(room.id)
    expect(message.dig("attributes", "metadata", "status")).to eq("retrying")
    expect(message.dig("attributes", "assets")).to eq([])
  end

  it "returns TTS assets on room history messages" do
    assistant_message = create(:chat_message, room: room, role: "assistant", content: "Hello there")
    create(
      :asset,
      type: "audio",
      format: "audio",
      source: "upload",
      url: "https://cdn.example.com/speech.mp3",
      storage_key: "speech/tts/tts_of_message_#{assistant_message.id}",
      resource_model: "chat_message",
      resource_id: assistant_message.id
    )
    assistant_message.update!(
      metadata: assistant_message.metadata.merge(
        "tts_status" => Chat::Message::STATUSES[:completed]
      )
    )

    get "/v1/ai/history", params: { room_id: room.id }, headers: headers

    expect(response).to have_http_status(:ok)
    message = response_data.find { |item| item.dig("attributes", "id") == assistant_message.id }
    expect(message.dig("attributes", "metadata", "tts_status")).to eq("completed")
    expect(message.dig("attributes", "assets")).to contain_exactly(
      hash_including(
        "url" => "https://cdn.example.com/speech.mp3",
        "type" => "audio",
        "resource_model" => "chat_message",
        "resource_id" => assistant_message.id
      )
    )
  end

  it "protects processing rooms from clearing or deletion" do
    create(:chat_message, room: room, metadata: { status: "queued" })

    delete "/v1/ai/clear", params: { room_id: room.id }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(room.reload.messages).to be_present

    delete "/v1/ai/rooms/#{room.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(Chat::Room).to exist(room.id)
  end

  describe "GET /v1/ai/rooms" do
    it "returns paginated rooms for the user" do
      create_list(:chat_room, 3, user: user)

      get "/v1/ai/rooms", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
    end
  end

  describe "POST /v1/ai/rooms" do
    it "creates a new room" do
      expect do
        post "/v1/ai/rooms", params: { title: "Custom Topic" }, headers: headers
      end.to change(user.rooms, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response_data.dig("room", "title")).to eq("Custom Topic")
    end
  end

  describe "PUT /v1/ai/rename" do
    it "renames a room" do
      put "/v1/ai/rename", params: { room_id: room.id, title: "Renamed Room" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(room.reload.title).to eq("Renamed Room")
    end
  end

  describe "DELETE /v1/ai/clear" do
    it "clears all messages from a room" do
      create_list(:chat_message, 2, room: room, metadata: { status: "completed" })

      delete "/v1/ai/clear", params: { room_id: room.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(room.reload.messages).to be_empty
    end
  end

  describe "POST /v1/ai/summarize" do
    it "summarizes text using AI client" do
      allow(AiService::Client).to receive(:chat)
        .and_return("choices" => [ { "message" => { "content" => "Summary result" } } ])

      post "/v1/ai/summarize", params: { text: "Long text to summarize" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("summary" => "Summary result")
    end
  end

  describe "POST /v1/ai/translate" do
    it "translates text using AI client" do
      allow(AiService::Client).to receive(:chat)
        .and_return("choices" => [ { "message" => { "content" => "Bonjour" } } ])

      post "/v1/ai/translate", params: { text: "Hello", language: "French" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("translation" => "Bonjour")
    end
  end

  describe "POST /v1/ai/analyze" do
    it "analyzes text using AI client" do
      allow(AiService::Client).to receive(:chat)
        .and_return("choices" => [ { "message" => { "content" => "Positive sentiment" } } ])

      post "/v1/ai/analyze", params: { text: "Great product!", type: "sentiment" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include("analysis" => "Positive sentiment")
    end
  end

  def grant_ai_permissions(account)
    role = create(:role, name: "ai_user")
    %w[create read update delete].each do |action|
      permission = create(:permission, action: action, resource: "ai")
      create(:role_permission, role: role, permission: permission)
    end
    create(:user_role, user: account, role: role)
  end
end
