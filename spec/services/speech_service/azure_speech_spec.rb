require "rails_helper"

class FakeAzureSocket
  attr_reader :frames, :types, :closed

  def initialize
    @frames = []
    @types = []
    @closed = false
  end

  def send(data, opt = { type: :text })
    @frames << data
    @types << opt[:type]
  end

  def close
    @closed = true
  end
end

RSpec.describe SpeechService::AzureSpeech do
  subject(:provider) { described_class.new }

  let(:socket) { FakeAzureSocket.new }
  let(:events) { [] }

  def start_session(language: "en-US")
    provider.start_live_stt(language: language, on_event: ->(event) { events << event }, socket: socket)
  end

  def audio_body(frame)
    header_length = frame.byteslice(0, 2).unpack1("n")
    frame.byteslice(2 + header_length..) || ""
  end

  it "sends speech.config as a text frame on start" do
    session = start_session

    expect(socket.frames.first).to include("Path: speech.config")
    expect(socket.frames.first).to include("rexone-core")
    expect(socket.frames.first).not_to include("X-RequestId")
    expect(socket.types.first).to eq(:text)
    session.stop
  end

  it "forwards PCM audio as a binary Path: audio frame" do
    session = start_session
    session.write_audio("pcm-bytes")

    frame = socket.frames.last
    expect(frame).to include("Path: audio")
    expect(frame).to include("audio/x-wav")
    expect(frame).to end_with("pcm-bytes")
    expect(socket.types.last).to eq(:binary)
    session.stop
  end

  it "prefixes binary frames with the big-endian header length" do
    session = start_session
    session.write_audio("pcm-bytes")

    frame = socket.frames.last
    header_length = frame.byteslice(0, 2).unpack1("n")
    expect(frame.byteslice(2, header_length)).to include("Path: audio")
    session.stop
  end

  it "opens the first audio chunk with a RIFF header" do
    session = start_session
    session.write_audio("pcm-bytes")
    session.write_audio("more-bytes")

    first_body = audio_body(socket.frames[1])
    second_body = audio_body(socket.frames[2])

    expect(first_body).to start_with("RIFF")
    expect(first_body.bytesize).to eq(44 + "pcm-bytes".bytesize)
    expect(second_body).to eq("more-bytes")
    session.stop
  end

  it "splits large audio payloads into Azure sized chunks" do
    session = start_session
    session.write_audio("a" * 10_000)

    audio_frames = socket.frames.drop(1)
    expect(audio_frames.size).to be > 1
    expect(audio_frames.map { |frame| audio_body(frame).bytesize }.max)
      .to be <= SpeechConstants::Live::MAX_AUDIO_CHUNK_BYTES
    session.stop
  end

  it "sends a zero-length audio frame on stop" do
    session = start_session
    session.write_audio("pcm-bytes")
    session.stop

    expect(audio_body(socket.frames.last)).to eq("")
    expect(socket.closed).to be(true)
  end

  it "maps speech.hypothesis to a partial event" do
    session = start_session
    session.handle_raw_message(%(Path: speech.hypothesis\r\n\r\n{"Text":"hello"}))

    expect(events).to eq([ { type: "partial", text: "hello" } ])
    session.stop
  end

  it "maps speech.phrase DisplayText to a final event" do
    session = start_session
    session.handle_raw_message(%(Path: speech.phrase\r\n\r\n{"RecognitionStatus":"Success","DisplayText":"Hello."}))

    expect(events).to eq([ { type: "final", text: "Hello." } ])
    session.stop
  end

  it "maps speech.phrase Text when DisplayText is missing" do
    session = start_session
    session.handle_raw_message(%(Path: speech.phrase\r\n\r\n{"Text":"Hello"}))

    expect(events).to eq([ { type: "final", text: "Hello" } ])
    session.stop
  end

  it "emits a localized error when Azure is not configured and no socket is injected" do
    stub_const("AppConfig::AZURE_SPEECH_KEY", "")

    session = provider.start_live_stt(on_event: ->(event) { events << event })

    expect(events).to eq([
      {
        type: "error",
        error: MessageService::Speech.t(MessageService::Speech::LIVE_NOT_CONFIGURED)
      }
    ])
    session.stop
  end
end
