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

    it "chunks long prompts into sequential user messages sharing split_id" do
      long_prompt = "Alpha " * 400 + "\n\n" + "Beta " * 400

      result = described_class.queue_ai_response!(
        user: user,
        room: room,
        content: long_prompt
      )

      expect(result.messages.size).to be > 1
      expect(result.message).to eq(result.messages.last)
      expect(result.message.ai_status).to eq(Chat::Message::STATUSES[:queued])

      split_ids = result.messages.map { |m| m.metadata[AiConstants::ChunkMetadata::SPLIT_ID] }
      expect(split_ids.uniq.size).to eq(1)
      expect(split_ids.first).to be_present

      result.messages.each_with_index do |m, idx|
        expect(m.metadata[AiConstants::ChunkMetadata::CHUNK_INDEX]).to eq(idx)
        expect(m.metadata[AiConstants::ChunkMetadata::TOTAL_CHUNKS]).to eq(result.messages.size)
      end
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

    it "chunks long assistant response into multiple assistant messages" do
      long_response = ("Insightful paragraph about mindfulness and meditation. " * 30 + "\n\n") * 3
      fake_response = {
        "id" => "resp-456",
        "choices" => [ { "message" => { "content" => long_response } } ],
        "usage" => { "prompt_tokens" => 5, "completion_tokens" => 500, "total_tokens" => 505 }
      }
      allow(Ai::RunService).to receive(:execute_chat).and_return(fake_response)

      described_class.process_ai_response!(user_message.id)

      expect(user_message.reload.ai_status).to eq(Chat::Message::STATUSES[:completed])
      assistant_messages = room.messages.where(role: AiConstants::ChatRole::ASSISTANT).chronological
      expect(assistant_messages.size).to be > 1
      expect(user_message.ai_assistant_message_id).to eq(assistant_messages.first.id)

      split_ids = assistant_messages.map { |m| m.metadata[AiConstants::ChunkMetadata::SPLIT_ID] }
      expect(split_ids.uniq.size).to eq(1)
      expect(split_ids.first).to be_present
    end

    it "stitches chunked user messages when passing conversation to AI runner" do
      room.messages.create!(
        role: AiConstants::ChatRole::USER,
        content: "Part 1 of question.",
        metadata: { "split_id" => "split-xyz", "chunk_index" => 0, "total_chunks" => 2 }
      )
      chunk2 = room.messages.create!(
        role: AiConstants::ChatRole::USER,
        content: "Part 2 of question.",
        ai_profile: profile,
        ai_status: Chat::Message::STATUSES[:queued],
        metadata: { "split_id" => "split-xyz", "chunk_index" => 1, "total_chunks" => 2 }
      )

      fake_response = {
        "id" => "resp-789",
        "choices" => [ { "message" => { "content" => "Combined answer." } } ],
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
      }

      expect(Ai::RunService).to receive(:execute_chat) do |args|
        user_msgs = args[:messages].select { |m| m[:role] == AiConstants::ChatRole::USER }
        expect(user_msgs.size).to eq(1)
        expect(user_msgs.first[:content]).to eq("Part 1 of question.\n\nPart 2 of question.")
        fake_response
      end

      described_class.process_ai_response!(chunk2.id)
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

    it "chunks long content into multiple messages sharing split_id" do
      long_msg = "Hello Direct " * 400
      messages = described_class.send_user_message!(
        user: user,
        room: room,
        content: long_msg
      )

      expect(messages).to be_an(Array)
      expect(messages.size).to be > 1
      split_ids = messages.map { |m| m.metadata[AiConstants::ChunkMetadata::SPLIT_ID] }
      expect(split_ids.uniq.size).to eq(1)
    end
  end

  describe ".clear_history!" do
    it "clears all messages from room" do
      create_list(:chat_message, 3, room: room)
      expect { described_class.clear_history!(room) }.to change(room.messages, :count).from(3).to(0)
    end
  end
end
