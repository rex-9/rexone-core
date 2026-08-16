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
end
