require "rails_helper"

RSpec.describe Chat::MessageSerializer do
  def serialized_attributes(message)
    described_class.new(message).serializable_hash[:data][:attributes]
  end

  it "exposes TTS state in metadata and an empty assets list by default" do
    message = build(
      :chat_message,
      role: "assistant",
      content: "Hello",
      tts_status: Chat::Message::STATUSES[:queued],
      tts_error: nil
    )

    attributes = serialized_attributes(message)

    expect(attributes).to include(content: "Hello", assets: [])
    expect(attributes[:metadata]).to include("tts_status" => "queued")
    expect(attributes).not_to have_key(:tts_status)
    expect(attributes).not_to have_key(:tts_error)
    expect(attributes).not_to have_key("audio_url")
  end

  it "nests linked assets as full AssetSerializer objects" do
    message = create(:chat_message, role: "assistant", content: "Speak this")
    asset = create(
      :asset,
      type: "audio",
      format: "audio",
      source: "upload",
      url: "https://cdn.example.com/speech.mp3",
      storage_key: "speech/tts/tts_of_message_#{message.id}",
      resource_model: "chat_message",
      resource_id: message.id
    )

    attributes = serialized_attributes(message.reload)

    expect(attributes[:metadata]["tts_status"]).to be_nil
    expect(attributes[:assets]).to contain_exactly(
      hash_including(
        id: asset.id,
        url: "https://cdn.example.com/speech.mp3",
        type: "audio",
        format: "audio",
        resource_model: "chat_message",
        resource_id: message.id
      )
    )
  end
end
