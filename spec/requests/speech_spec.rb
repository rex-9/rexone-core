require "rails_helper"

RSpec.describe "Speech synthesis", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:tts_result) do
    {
      audio: { data: "BASE64", format: "wav", sample_rate: 16_000 },
      visemes: [ { audio_offset: 500_000, viseme_id: 12, audio_offset_ms: 50 } ]
    }
  end

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_speech_permissions(user)
  end

  it "returns provider audio and visemes for a synthesis request" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: "en-US-Ava")
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello", voiceName: "en-US-Ava" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data).to include(
      "audio" => { "data" => "BASE64", "format" => "wav", "sample_rate" => 16_000 },
      "visemes" => [ { "audio_offset" => 500_000, "viseme_id" => 12, "audio_offset_ms" => 50 } ]
    )
  end

  it "synthesizes without a voice when none is supplied" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: nil)
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello" }, headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "does not accept snake_case voice_name" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: nil)
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello", voice_name: "en-US-Ava" }, headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "rejects a blank text without calling the provider" do
    expect(SpeechService::Client).not_to receive(:text_to_speech)

    post "/v1/speech/tts", params: { text: "" }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "surfaces provider failures as a server error" do
    allow(SpeechService::Client).to receive(:text_to_speech).and_return(error: "Speech service is unavailable")

    post "/v1/speech/tts", params: { text: "Hello" }, headers: headers

    expect(response).to have_http_status(:internal_server_error)
    expect(response_status["error"]).to eq("Speech service is unavailable")
  end

  it "denies users without speech permissions" do
    other = create(:user)
    allow(CacheService).to receive(:read).and_return(jwt_for(other))

    post "/v1/speech/tts", params: { text: "Hello" }, headers: authorization_headers(jwt_for(other))

    expect(response).to have_http_status(:forbidden)
  end

  describe "POST /v1/speech/stt-url" do
    it "returns transcribed text for a valid audioUrl" do
      expect(SpeechService::Client).to receive(:speech_to_text_with_url)
        .with(audioUrl: "https://cdn.example.com/audio.wav")
        .and_return(text: "hello")

      post "/v1/speech/stt-url",
           params: { audioUrl: "https://cdn.example.com/audio.wav" },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("text" => "hello")
    end

    it "rejects a blank audioUrl without calling the provider" do
      expect(SpeechService::Client).not_to receive(:speech_to_text_with_url)

      post "/v1/speech/stt-url", params: { audioUrl: "" }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not accept snake_case audio_url" do
      expect(SpeechService::Client).not_to receive(:speech_to_text_with_url)

      post "/v1/speech/stt-url",
           params: { audio_url: "https://cdn.example.com/audio.wav" },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "surfaces provider failures as a server error" do
      allow(SpeechService::Client).to receive(:speech_to_text_with_url)
        .and_return(error: "Speech service is unavailable")

      post "/v1/speech/stt-url",
           params: { audioUrl: "https://cdn.example.com/audio.wav" },
           headers: headers

      expect(response).to have_http_status(:internal_server_error)
      expect(response_status["error"]).to eq("Speech service is unavailable")
    end
  end

  def grant_speech_permissions(account)
    role = create(:role, name: "speech_user")
    permission = create(:permission, action: "create", resource: "speech")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: account, role: role)
  end
end
