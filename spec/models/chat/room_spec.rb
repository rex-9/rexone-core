require "rails_helper"

RSpec.describe Chat::Room, type: :model do
  it "requires a title and belongs to a user" do
    expect(build(:chat_room)).to be_valid
    expect(build(:chat_room, title: nil)).not_to be_valid
    expect(build(:chat_room, user: nil)).not_to be_valid
  end

  it "counts and returns its last message" do
    room = create(:chat_room)
    first = create(:chat_message, room: room, content: "First")
    last = create(:chat_message, room: room, role: "assistant", content: "Last")
    expect(room.message_count).to eq(2)
    expect(room.last_message).to eq(last)
    expect(room.last_message).not_to eq(first)
  end

  it "uses the first user message as a truncated title" do
    room = create(:chat_room, title: "New Conversation")
    content = "A" * 60
    create(:chat_message, room: room, content: content)
    room.update_title_from_first_message!
    expect(room.reload.title).to eq(content.truncate(50))
  end

  it "does not title a room from an assistant message" do
    room = create(:chat_room, title: "Original")
    create(:chat_message, room: room, role: "assistant")
    expect { room.update_title_from_first_message! }.not_to change(room, :title)
  end

  it "reports whether AI work is still pending" do
    room = create(:chat_room)
    message = create(:chat_message, room: room, metadata: { status: "processing" })

    expect(room).to be_processing
    message.update!(metadata: { status: "completed" })
    expect(room).not_to be_processing
  end
end
