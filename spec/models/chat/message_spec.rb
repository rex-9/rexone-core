require "rails_helper"

RSpec.describe Chat::Message, type: :model do
  it "accepts user and assistant messages only" do
    expect(build(:chat_message, role: "user")).to be_valid
    expect(build(:chat_message, role: "assistant")).to be_valid
    expect(build(:chat_message, role: "system")).not_to be_valid
    expect(build(:chat_message, content: nil)).not_to be_valid
  end

  it "exposes role helpers" do
    user_message = build(:chat_message, role: "user")
    assistant_message = build(:chat_message, role: "assistant")
    expect(user_message).to be_user
    expect(user_message).not_to be_assistant
    expect(assistant_message).to be_assistant
  end

  it "orders conversation history chronologically" do
    room = create(:chat_room)
    later = create(:chat_message, room: room, created_at: 1.hour.from_now)
    earlier = create(:chat_message, room: room, created_at: 1.hour.ago)
    expect(room.messages.chronological).to eq([ earlier, later ])
  end

  it "identifies durable AI processing states" do
    room = create(:chat_room)
    queued = create(:chat_message, room: room, metadata: { status: "queued" })
    completed = create(:chat_message, room: room, metadata: { status: "completed" })

    expect(queued).to be_ai_processing
    expect(completed).not_to be_ai_processing
    expect(room.messages.ai_processing).to contain_exactly(queued)
  end

  it "declares the supported AI metadata fields" do
    message = build(
      :chat_message,
      ai_status: described_class::AI_STATUSES[:queued],
      ai_temperature: 0.4,
      ai_max_tokens: 500
    )

    expect(message).to have_attributes(
      ai_status: "queued",
      ai_temperature: 0.4,
      ai_max_tokens: 500
    )
  end
end
