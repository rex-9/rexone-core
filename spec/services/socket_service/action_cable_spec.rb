require "rails_helper"

RSpec.describe SocketService::ActionCable do
  subject(:provider) { described_class.new }

  it "broadcasts the frontend notification envelope" do
    allow(ActionCable.server).to receive(:broadcast)
    travel_to(Time.zone.parse("2026-01-01 12:00:00 UTC")) do
      expect(provider.broadcast(user_id: "user-id", message: "Hello", data: { type: "welcome" })).to be(true)
    end
    expect(ActionCable.server).to have_received(:broadcast).with(
      "notification_user_user-id",
      type: "notification", message: "Hello", data: { type: "welcome" }, created_at: "2026-01-01T12:00:00Z"
    )
  end

  it "returns nil when notification broadcasting fails" do
    allow(ActionCable.server).to receive(:broadcast).and_raise("cable unavailable")
    expect(provider.broadcast(user_id: "user-id", message: "Hello")).to be_nil
  end

  it "broadcasts generic channel messages" do
    allow(ActionCable.server).to receive(:broadcast).and_return("ok")
    expect(provider.broadcast_to_channel(channel: "room", message: "Hello", data: { id: 1 })).to eq("ok")
    expect(ActionCable.server).to have_received(:broadcast).with(
      "room", type: "message", message: "Hello", data: { id: 1 }
    )
  end
end
