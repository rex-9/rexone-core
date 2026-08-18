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
    expect(response_data).to include("room_id" => room.id, "processing" => true)
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

  def grant_ai_permissions(account)
    role = create(:role, name: "ai_user")
    %w[create read delete].each do |action|
      permission = create(:permission, action: action, resource: "ai")
      create(:role_permission, role: role, permission: permission)
    end
    create(:user_role, user: account, role: role)
  end
end
