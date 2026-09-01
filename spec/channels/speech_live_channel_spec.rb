require "rails_helper"
require "base64"

RSpec.describe SpeechLiveChannel, type: :channel do
  let(:user) { create(:user) }
  let(:session) { instance_double(SpeechService::Session, write_audio: true, stop: true, idle?: false) }

  before do
    allow(SpeechService::Client).to receive(:start_live_stt).and_return(session)
  end

  it "rejects users without speech create permission" do
    stub_connection current_user: user

    subscribe

    expect(subscription).to be_rejected
  end

  context "with speech create permission" do
    before do
      grant_permissions(user, "speech", "create")
      stub_connection current_user: user
    end

    it "subscribes and starts a live Azure session" do
      subscribe(language: "en-US")

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("speech_live_user_#{user.id}")
      expect(SpeechService::Client).to have_received(:start_live_stt).with(
        hash_including(language: "en-US")
      )
    end

    it "forwards base64 audio to the session" do
      subscribe
      perform :audio, chunk: Base64.strict_encode64("pcm")

      expect(session).to have_received(:write_audio).with("pcm")
    end

    it "stops the Azure session on stop" do
      subscribe
      perform :stop

      expect(session).to have_received(:stop)
    end

    it "stops the Azure session on unsubscribe" do
      subscribe
      unsubscribe

      expect(session).to have_received(:stop)
    end

    it "broadcasts transcripts in the channel message envelope" do
      on_event = nil
      allow(SpeechService::Client).to receive(:start_live_stt) do |**kwargs|
        on_event = kwargs[:on_event]
        session
      end

      subscribe

      expect {
        on_event.call(type: "partial", text: "hello")
      }.to have_broadcasted_to("speech_live_user_#{user.id}").with(
        type: "message",
        message: "hello",
        data: { type: "partial", text: "hello" }
      )
    end

    it "broadcasts localized errors in the channel message envelope" do
      on_event = nil
      allow(SpeechService::Client).to receive(:start_live_stt) do |**kwargs|
        on_event = kwargs[:on_event]
        session
      end

      subscribe

      expect {
        on_event.call(type: "error", error: "Live transcription is not configured")
      }.to have_broadcasted_to("speech_live_user_#{user.id}").with(
        type: "message",
        message: "Live transcription is not configured",
        data: { type: "error", error: "Live transcription is not configured" }
      )
    end
  end
end
