# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::MessageService do
  let(:user) { create(:user) }
  let(:room) { create(:chat_room, user: user) }
  let!(:profile) { Ai::ProfileService.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT) }

  describe ".queue_ai_response!" do
    it "persists queued user message and enqueues background job" do
      expect {
        result = described_class.queue_ai_response!(
          user: user,
          room: room,
          content: "Explain quantum computing in one sentence."
        )

        expect(result.message).to be_persisted
        expect(result.message.role).to eq(AiConstants::ChatRole::USER)
        expect(result.message.ai_status).to eq(Chat::Message::STATUSES[:queued])
        expect(result.message.ai_profile).to eq(profile)
        expect(result.job).to be_present
      }.to have_enqueued_job(Chat::ProcessMessageJob)
    end

    it "raises error if room is already busy processing" do
      create(:chat_message, room: room, role: "user", metadata: { "status" => "processing" })

      expect {
        described_class.queue_ai_response!(
          user: user,
          room: room,
          content: "Another prompt"
        )
      }.to raise_error(Chat::MessageService::Error, /already/i)
    end
  end

  describe ".process_ai_response!" do
    let(:user_message) do
      room.messages.create!(
        role: AiConstants::ChatRole::USER,
        content: "Hello",
        ai_profile: profile,
        ai_status: Chat::Message::STATUSES[:queued]
      )
    end

    it "completes execution and creates assistant response" do
      fake_response = {
        "id" => "resp-123",
        "choices" => [ { "message" => { "content" => "Hello! How can I assist you today?" } } ],
        "usage" => { "prompt_tokens" => 5, "completion_tokens" => 9, "total_tokens" => 14 }
      }
      allow(Ai::RunService).to receive(:execute_chat).and_return(fake_response)

      described_class.process_ai_response!(user_message.id)

      expect(user_message.reload.ai_status).to eq(Chat::Message::STATUSES[:completed])
      assistant_message = Chat::Message.find(user_message.ai_assistant_message_id)
      expect(assistant_message.role).to eq(AiConstants::ChatRole::ASSISTANT)
      expect(assistant_message.content).to eq("Hello! How can I assist you today?")
    end
  end

  describe ".send_user_message!" do
    it "creates a user message without triggering AI processing" do
      message = described_class.send_user_message!(
        user: user,
        room: room,
        content: "Hello in direct chat"
      )

      expect(message).to be_persisted
      expect(message.role).to eq(AiConstants::ChatRole::USER)
      expect(message.content).to eq("Hello in direct chat")
      expect(message.ai_status).to be_nil
    end
  end

  describe ".clear_history!" do
    it "clears all messages from room" do
      create_list(:chat_message, 3, room: room)
      expect { described_class.clear_history!(room) }.to change(room.messages, :count).from(3).to(0)
    end
  end
end
