require "rails_helper"

RSpec.describe Speech::ProcessTtsJob, type: :job do
  let(:room) { create(:chat_room) }
  let(:message) { create(:chat_message, room: room, role: "assistant", content: "Hello there") }
  let(:storage_key) { "speech/tts/#{AssetConstants::AssetName.tts_for_message(message.id)}" }

  before do
    allow(NotificationService).to receive(:notify)
  end

  it "synthesizes, uploads, persists an audio Asset, and notifies readiness" do
    allow(SpeechService::Client).to receive(:text_to_speech).and_return(
      bytes: "ID3fake",
      content_type: "audio/mpeg",
      filename: "speech.mp3"
    )
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: storage_key,
      url: "https://cdn.example.com/speech.mp3",
      bytes: 12345,
      format: "mp3"
    )

    expect { described_class.perform_now(message.id) }.to change(Asset, :count).by(1)

    message.reload
    asset = message.tts_asset
    expect(asset).to have_attributes(
      name: AssetConstants::AssetName.tts_for_message(message.id),
      url: "https://cdn.example.com/speech.mp3",
      type: "audio",
      format: "audio",
      extension: "mp3",
      size_bytes: 12345,
      source: "upload",
      storage_key: storage_key,
      resource_model: "chat_message",
      resource_id: message.id
    )
    expect(message).to have_attributes(
      tts_status: "completed",
      tts_error: nil
    )
    expect(SpeechService::Client).to have_received(:text_to_speech).with(text: "Hello there")
    expect(StorageService::Client).to have_received(:upload).with(
      anything,
      hash_including(
        storage_key: AssetConstants::AssetName.tts_for_message(message.id),
        folder: "speech/tts",
        resource_type: "video",
        overwrite: true
      )
    )
    expect(NotificationService).to have_received(:notify).with(
      hash_including(
        user_id: room.user_id,
        send_socket: true,
        data: hash_including(
          type: "tts_ready",
          message_id: message.id,
          room_id: room.id,
          assets: [
            hash_including(
              id: asset.id,
              url: "https://cdn.example.com/speech.mp3",
              type: "audio",
              resource_model: "chat_message",
              resource_id: message.id
            )
          ]
        )
      )
    )
  end

  it "overwrites the existing audio Asset on re-TTS instead of creating another" do
    existing = create(
      :asset,
      type: "audio",
      format: "audio",
      source: "upload",
      name: AssetConstants::AssetName.tts_for_message(message.id),
      url: "https://cdn.example.com/old.mp3",
      storage_key: storage_key,
      resource_model: "chat_message",
      resource_id: message.id
    )
    message.update!(metadata: message.metadata.merge("tts_status" => "queued"))

    allow(SpeechService::Client).to receive(:text_to_speech).and_return(
      bytes: "ID3fake",
      content_type: "audio/mpeg",
      filename: "speech.mp3"
    )
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: storage_key,
      url: "https://cdn.example.com/new.mp3",
      bytes: 99,
      format: "mp3"
    )

    expect { described_class.perform_now(message.id) }.not_to change(Asset, :count)

    expect(existing.reload.url).to eq("https://cdn.example.com/new.mp3")
    expect(message.reload.tts_status).to eq("completed")
  end

  it "is idempotent once TTS has completed" do
    message.update!(metadata: message.metadata.merge("tts_status" => "completed"))
    allow(SpeechService::Client).to receive(:text_to_speech)

    described_class.perform_now(message.id)

    expect(SpeechService::Client).not_to have_received(:text_to_speech)
  end

  it "schedules provider failures for retry" do
    allow(SpeechService::Client).to receive(:text_to_speech).and_return(error: "temporarily unavailable")

    expect do
      described_class.perform_now(message.id)
    end.to have_enqueued_job(described_class).with(message.id)

    expect(message.reload.tts_status).to eq("retrying")
    expect(message.tts_error).to eq("temporarily unavailable")
  end

  it "records unexpected terminal failures and alerts the user" do
    allow(SpeechService::Client).to receive(:text_to_speech).and_raise(RuntimeError, "broken")

    expect { described_class.perform_now(message.id) }.to raise_error(RuntimeError, "broken")
    expect(message.reload.tts_status).to eq("failed")
    expect(message.tts_error).to eq("broken")
    expect(NotificationService).to have_received(:notify).with(
      hash_including(
        data: hash_including(type: "tts_failed", assets: []),
        send_socket: true
      )
    )
  end
end
