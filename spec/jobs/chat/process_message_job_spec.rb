require "rails_helper"

RSpec.describe Chat::ProcessMessageJob, type: :job do
  let(:room) { create(:chat_room, title: "New Conversation") }
  let(:user_message) do
    profile = create(:ai_profile, key: AiConstants::ProfileKey::CHAT_DEFAULT, temperature: 0.4, max_output_tokens: 500)
    create(
      :chat_message,
      room: room,
      ai_profile: profile,
      content: "How are you?",
      metadata: { status: "queued", temperature: 0.4, max_tokens: 500 }
    )
  end
  let(:result) do
    {
      "choices" => [ { "message" => { "content" => "Doing well." } } ],
      "usage" => { "total_tokens" => 12 },
      "model" => "deepseek-chat"
    }
  end

  before do
    allow(NotificationService::Center).to receive(:notify)
  end

  it "persists the response, completes the request, and broadcasts readiness" do
    allow(Ai::Providers::Client).to receive(:chat).and_return(result)

    described_class.perform_now(user_message.id)

    assistant = room.messages.find_by!(role: "assistant")
    expect(assistant).to have_attributes(content: "Doing well.")
    expect(assistant.metadata).to include("model" => "deepseek-chat")
    expect(user_message.reload.metadata).to include(
      "status" => "completed",
      "assistant_message_id" => assistant.id
    )
    expect(user_message.ai_error).to be_nil
    expect(room.reload.title).to eq("How are you?")
    expect(Ai::Providers::Client).to have_received(:chat).with(
      messages: [ { role: "user", content: "How are you?" } ],
      model: user_message.ai_profile.model,
      temperature: 0.4,
      max_tokens: 500,
      timeout_seconds: user_message.ai_profile.timeout_seconds,
      provider: user_message.ai_profile.provider
    )
    expect(Ai::Run.last).to have_attributes(
      chat_message: user_message,
      feature: AiConstants::RunFeature::CHAT,
      status: AiConstants::RunStatus::COMPLETED,
      total_tokens: 12
    )
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(user_id: room.user_id, data: hash_including(type: "ai_response_ready"), send_socket: true)
    )
  end

  it "prepends a system message when system_prompt is present" do
    user_message.update!(metadata: user_message.metadata.merge("system_prompt" => "You are a helpful assistant."))
    allow(Ai::Providers::Client).to receive(:chat).and_return(result)

    described_class.perform_now(user_message.id)

    expect(Ai::Providers::Client).to have_received(:chat).with(
      messages: [
        { role: AiConstants::ChatRole::SYSTEM, content: "You are a helpful assistant." },
        { role: "user", content: "How are you?" }
      ],
      model: user_message.ai_profile.model,
      temperature: 0.4,
      max_tokens: 500,
      timeout_seconds: user_message.ai_profile.timeout_seconds,
      provider: user_message.ai_profile.provider
    )
  end

  it "is idempotent once the request has completed" do
    user_message.update!(metadata: user_message.metadata.merge("status" => "completed"))
    allow(Ai::Providers::Client).to receive(:chat)

    expect { described_class.perform_now(user_message.id) }.not_to change(Chat::Message, :count)
    expect(Ai::Providers::Client).not_to have_received(:chat)
  end

  it "schedules provider failures for retry without unlocking the room" do
    allow(Ai::Providers::Client).to receive(:chat).and_return(error: "temporarily unavailable")

    expect do
      described_class.perform_now(user_message.id)
    end.to have_enqueued_job(described_class).with(user_message.id)

    expect(user_message.reload.metadata).to include(
      "status" => "retrying",
      "error" => "temporarily unavailable"
    )
    expect(room).to be_processing
  end

  it "records unexpected terminal failures and alerts the user" do
    allow(Ai::Providers::Client).to receive(:chat).and_raise(RuntimeError, "broken")

    expect { described_class.perform_now(user_message.id) }.to raise_error(RuntimeError, "broken")
    expect(user_message.reload.metadata).to include("status" => "failed", "error" => "broken")
    expect(room).not_to be_processing
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(data: hash_including(type: "ai_response_failed"), send_socket: true)
    )
  end
end
