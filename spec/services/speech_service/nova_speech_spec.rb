require "rails_helper"

RSpec.describe SpeechService::NovaSpeech do
  subject(:provider) { described_class.new }

  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  it "posts the text and maps the camelCase provider payload to snake_case" do
    body = {
      audio: { data: "BASE64", format: "wav", sampleRate: 16_000 },
      visemes: [ { audioOffset: 500_000, visemeId: 12, audioOffsetMs: 50 } ]
    }.to_json
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      instance_double(Net::HTTPResponse, code: "200", body: body)
    end

    result = provider.text_to_speech(text: "Hello", voice_name: "en-US-Ava")

    expect(result).to eq(
      audio: { data: "BASE64", format: "wav", sample_rate: 16_000 },
      visemes: [ { audio_offset: 500_000, viseme_id: 12, audio_offset_ms: 50 } ]
    )
    expect(JSON.parse(request.body)).to eq("text" => "Hello", "voiceName" => "en-US-Ava")
    expect(request["Content-Type"]).to eq("application/json")
  end

  it "omits voiceName when no voice is requested" do
    allow(http).to receive(:request) do |value|
      expect(JSON.parse(value.body)).to eq("text" => "Hello")
      instance_double(Net::HTTPResponse, code: "200", body: { audio: {}, visemes: [] }.to_json)
    end

    expect(provider.text_to_speech(text: "Hello")).to include(visemes: [])
  end

  it "returns a localized provider error for HTTP, parse, and network failures" do
    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "500", body: "boom"))
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present

    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "200", body: "not json"))
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present

    allow(http).to receive(:request).and_raise(Timeout::Error)
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present
  end
end
