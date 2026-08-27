require "rails_helper"

RSpec.describe Speech::ProcessTtsJob, type: :job do
  let(:room) { create(:chat_room) }
  let(:message) { create(:chat_message, room: room, role: "assistant", content: "Hello there") }

  before do
    allow(NotificationService).to receive(:notify)
  end

  it "synthesizes, uploads, stores audio_url, and notifies readiness" do
    allow(SpeechService::Client).to receive(:text_to_speech).and_return(
      bytes: "ID3fake",
      content_type: "audio/mpeg",
      filename: "speech.mp3"
    )
    allow(StorageService::Client).to receive(:upload).and_return(
      public_id: "speech/tts/message_#{message.id}",
      url: "https://cdn.example.com/speech.mp3"
    )

    described_class.perform_now(message.id)

    expect(message.reload).to have_attributes(
      audio_url: "https://cdn.example.com/speech.mp3",
      tts_status: "completed",
      tts_error: nil
    )
    expect(SpeechService::Client).to have_received(:text_to_speech).with(text: "Hello there")
    expect(StorageService::Client).to have_received(:upload).with(
      anything,
      hash_including(
        public_id: "message_#{message.id}",
        folder: "speech/tts",
        resource_type: "raw",
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
          audio_url: "https://cdn.example.com/speech.mp3"
        )
      )
    )
  end

  it "is idempotent once TTS has completed" do
    message.update!(metadata: message.metadata.merge("tts_status" => "completed", "audio_url" => "https://cdn.example.com/old.mp3"))
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
      hash_including(data: hash_including(type: "tts_failed"), send_socket: true)
    )
  end
end
