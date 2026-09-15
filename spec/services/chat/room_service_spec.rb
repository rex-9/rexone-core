# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::RoomService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe ".list" do
    it "returns kept rooms for the user ordered by recent" do
      old_room = create(:chat_room, user: user, created_at: 2.days.ago)
      new_room = create(:chat_room, user: user, created_at: 1.day.ago)
      discarded_room = create(:chat_room, user: user, discarded_at: Time.current)
      other_room = create(:chat_room, user: other_user)

      results = described_class.list(user)
      expect(results).to include(new_room, old_room)
      expect(results).not_to include(discarded_room, other_room)
      expect(results.first).to eq(new_room)
    end
  end

  describe ".admin_list" do
    it "filters rooms by discarded and user_id" do
      kept_room = create(:chat_room, user: user)
      discarded_room = create(:chat_room, user: user, discarded_at: Time.current)

      expect(described_class.admin_list).to include(kept_room)
      expect(described_class.admin_list).not_to include(discarded_room)

      discarded_list = described_class.admin_list(discarded: "true")
      expect(discarded_list).to include(discarded_room)
      expect(discarded_list).not_to include(kept_room)
    end
  end

  describe ".create!" do
    it "creates a room with custom or default title" do
      room = described_class.create!(user, title: "Special Project")
      expect(room.title).to eq("Special Project")
      expect(room.user).to eq(user)

      default_room = described_class.create!(user)
      expect(default_room.title).to be_present
    end
  end

  describe ".update!" do
    it "updates room title" do
      room = create(:chat_room, user: user, title: "Old Title")
      described_class.update!(room, title: "New Title")
      expect(room.reload.title).to eq("New Title")
    end
  end

  describe ".destroy!" do
    it "destroys room when not busy" do
      room = create(:chat_room, user: user)
      expect { described_class.destroy!(room) }.to change(Chat::Room, :count).by(-1)
    end

    it "raises RoomBusyError when room has in-flight message" do
      room = create(:chat_room, user: user)
      create(:chat_message, room: room, role: "user", metadata: { "status" => "processing" })

      expect {
        described_class.destroy!(room)
      }.to raise_error(Chat::RoomService::RoomBusyError)
    end
  end
end
