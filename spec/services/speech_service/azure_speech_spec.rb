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

  describe "#text_to_speech" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      stub_const("AppConfig::AZURE_SPEECH_KEY", "test-key")
      stub_const("AppConfig::AZURE_SPEECH_REGION", "southeastasia")
      stub_const("AppConfig::AZURE_SPEECH_LANGUAGE", "en-US")
      stub_const("AppConfig::AZURE_SPEECH_VOICE", "en-US-AvaNeural")

      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "posts SSML to Azure and returns MP3 bytes" do
      request = nil
      allow(http).to receive(:request) do |value|
        request = value
        instance_double(Net::HTTPResponse, code: "200", body: "ID3fake")
      end

      result = provider.text_to_speech(text: "Hello <world>", voice_name: "en-US-JennyNeural")

      expect(result).to eq(
        bytes: "ID3fake",
        content_type: "audio/mpeg",
        filename: "speech.mp3"
      )
      expect(request["Content-Type"]).to eq("application/ssml+xml")
      expect(request["Ocp-Apim-Subscription-Key"]).to eq("test-key")
      expect(request["X-Microsoft-OutputFormat"]).to eq("audio-16khz-128kbitrate-mono-mp3")
      expect(request["User-Agent"]).to eq("rexone-core")
      expect(request.body).to include('xml:lang="en-US"')
      expect(request.body).to include('name="en-US-JennyNeural"')
      expect(request.body).to include("Hello &lt;world&gt;")
      expect(request.body).not_to include("Hello <world>")
    end

    it "uses the configured default voice when none is passed" do
      allow(http).to receive(:request) do |value|
        expect(value.body).to include('name="en-US-AvaNeural"')
        instance_double(Net::HTTPResponse, code: "200", body: "ID3fake")
      end

      expect(provider.text_to_speech(text: "Hello")).to include(bytes: "ID3fake")
    end

    it "returns a localized error when the key is blank" do
      stub_const("AppConfig::AZURE_SPEECH_KEY", "")

      expect(provider.text_to_speech(text: "Hello")[:error])
        .to eq(MessageService::Speech.t(MessageService::Speech::PROVIDER_ERROR))
    end

    it "returns a localized error for HTTP and network failures" do
      allow(http).to receive(:request)
        .and_return(instance_double(Net::HTTPResponse, code: "500", body: "boom"))
      expect(provider.text_to_speech(text: "Hello")[:error]).to be_present

      allow(http).to receive(:request).and_raise(Timeout::Error)
      expect(provider.text_to_speech(text: "Hello")[:error]).to be_present
    end
  end
end
