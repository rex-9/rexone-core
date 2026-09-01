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

  def tts_multipart_response(audio_bytes: "ID3fake", filename: "speech.mp3")
    boundary = "----ttsboundary"
    body = +""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"audio\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: audio/mpeg\r\n"
    body << "\r\n"
    body << audio_bytes
    body << "\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"meta\"\r\n"
    body << "Content-Type: application/json\r\n"
    body << "\r\n"
    body << { success: true }.to_json
    body << "\r\n"
    body << "--#{boundary}--"

    response = instance_double(Net::HTTPResponse, code: "200", body: body)
    allow(response).to receive(:[]).with("Content-Type")
      .and_return("multipart/form-data; boundary=#{boundary}")
    response
  end

  it "posts returnFile and extracts the multipart audio part" do
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      tts_multipart_response
    end

    result = provider.text_to_speech(text: "Hello", voice_name: "en-US-Ava")

    expect(result).to eq(
      bytes: "ID3fake",
      content_type: "audio/mpeg",
      filename: "speech.mp3"
    )
    expect(JSON.parse(request.body)).to eq(
      "text" => "Hello",
      "voiceName" => "en-US-Ava",
      "returnFile" => true
    )
    expect(request["Content-Type"]).to eq("application/json")
  end

  it "omits voiceName when no voice is requested" do
    allow(http).to receive(:request) do |value|
      expect(JSON.parse(value.body)).to eq("text" => "Hello", "returnFile" => true)
      tts_multipart_response
    end

    expect(provider.text_to_speech(text: "Hello")).to include(bytes: "ID3fake")
  end

  it "returns a localized provider error for HTTP, missing audio, and network failures" do
    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "500", body: "boom"))
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present

    allow(http).to receive(:request).and_return(
      instance_double(Net::HTTPResponse, code: "200", body: "not json").tap do |response|
        allow(response).to receive(:[]).with("Content-Type").and_return("application/json")
      end
    )
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present

    allow(http).to receive(:request).and_raise(Timeout::Error)
    expect(provider.text_to_speech(text: "Hello")[:error]).to be_present
  end

  it "posts multipart audio and maps the provider text response" do
    audio_file = nil
    audio_file = Tempfile.new([ "clip", ".m4a" ])
    audio_file.binmode
    audio_file.write("fake-audio")
    audio_file.rewind
    audio = ActionDispatch::Http::UploadedFile.new(
      tempfile: audio_file,
      filename: "clip.m4a",
      type: "audio/mp4"
    )
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      instance_double(Net::HTTPResponse, code: "200", body: { data: { text: "hello" } }.to_json)
    end

    result = provider.speech_to_text_from_file(audio: audio)

    expect(result).to eq(text: "hello")
    expect(request["Content-Type"]).to include("multipart/form-data")
  ensure
    audio_file&.close!
  end

  it "posts audioUrl and maps the provider text response" do
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      instance_double(Net::HTTPResponse, code: "200", body: { data: { text: "hello" } }.to_json)
    end

    result = provider.speech_to_text_from_url(audio_url: "https://cdn.example.com/audio.wav")

    expect(result).to eq(text: "hello")
    expect(JSON.parse(request.body)).to eq("audioUrl" => "https://cdn.example.com/audio.wav")
    expect(request["Content-Type"]).to eq("application/json")
  end

  it "returns a localized provider error for STT HTTP failures" do
    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "500", body: "boom"))
    expect(provider.speech_to_text_from_url(audio_url: "https://cdn.example.com/audio.wav")[:error]).to be_present
  end
end
