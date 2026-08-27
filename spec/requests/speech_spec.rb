require "rails_helper"

RSpec.describe "Speech synthesis", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:tts_result) do
    {
      bytes: "ID3fake",
      content_type: "audio/mpeg",
      filename: "speech.mp3"
    }
  end

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_speech_permissions(user)
  end

  it "returns an mp3 file for a synthesis request" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: "en-US-Ava")
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello", voice_name: "en-US-Ava" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("audio/mpeg")
    expect(response.body).to eq("ID3fake")
    expect(response.headers["Content-Disposition"]).to include("speech.mp3")
  end

  it "synthesizes without a voice when none is supplied" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: nil)
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello" }, headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "does not accept camelCase voiceName" do
    expect(SpeechService::Client).to receive(:text_to_speech)
      .with(text: "Hello", voice_name: nil)
      .and_return(tts_result)

    post "/v1/speech/tts", params: { text: "Hello", voiceName: "en-US-Ava" }, headers: headers

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

  describe "async TTS with message_id" do
    let(:room) { create(:chat_room, user: user) }
    let(:message) { create(:chat_message, room: room, role: "assistant", content: "Hello there") }

    it "queues TTS for an owned chat message" do
      expect(SpeechService::Client).not_to receive(:text_to_speech)

      expect {
        post "/v1/speech/tts",
             params: { message_id: message.id },
             headers: headers,
             as: :json
      }.to have_enqueued_job(Speech::ProcessTtsJob).with(message.id)

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "message_id" => message.id,
        "room_id" => room.id,
        "status" => "queued"
      )
      expect(response_data["job_id"]).to be_present
      expect(message.reload.tts_status).to eq("queued")
      expect(message.audio_url).to be_nil
    end

    it "returns 404 when the message belongs to another user" do
      other_message = create(:chat_message, role: "assistant", content: "Nope")

      expect {
        post "/v1/speech/tts",
             params: { message_id: other_message.id },
             headers: headers,
             as: :json
      }.not_to have_enqueued_job(Speech::ProcessTtsJob)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown message_id" do
      post "/v1/speech/tts",
           params: { message_id: SecureRandom.uuid },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "prefers message_id over text and does not synthesize sync" do
      expect(SpeechService::Client).not_to receive(:text_to_speech)

      post "/v1/speech/tts",
           params: { message_id: message.id, text: "ignored" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response_data["status"]).to eq("queued")
    end

    it "surfaces queue failures as service unavailable" do
      allow(Speech::ProcessTtsJob).to receive(:perform_later)
        .and_raise(SolidQueue::Job::EnqueueError.new("queue unavailable"))

      post "/v1/speech/tts",
           params: { message_id: message.id },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe "POST /v1/speech/stt" do
    let(:audio) { fixture_file_upload("clip.m4a", "audio/mp4") }

    it "returns transcribed text for an uploaded audio file" do
      expect(SpeechService::Client).to receive(:speech_to_text_from_file)
        .with(audio: kind_of(ActionDispatch::Http::UploadedFile))
        .and_return(text: "hello")
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_url)

      post "/v1/speech/stt", params: { audio: audio }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("text" => "hello")
    end

    it "returns transcribed text for a valid audio_url" do
      expect(SpeechService::Client).to receive(:speech_to_text_from_url)
        .with(audio_url: "https://cdn.example.com/audio.wav")
        .and_return(text: "hello")
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_file)

      post "/v1/speech/stt",
           params: { audio_url: "https://cdn.example.com/audio.wav" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("text" => "hello")
    end

    it "prefers an uploaded file when audio_url is also sent" do
      expect(SpeechService::Client).to receive(:speech_to_text_from_file)
        .with(audio: kind_of(ActionDispatch::Http::UploadedFile))
        .and_return(text: "from file")
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_url)

      post "/v1/speech/stt",
           params: { audio: audio, audio_url: "https://cdn.example.com/audio.wav" },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to eq("text" => "from file")
    end

    it "rejects a missing audio file and audio_url without calling the provider" do
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_file)
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_url)

      post "/v1/speech/stt", params: { audio_url: "" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not accept camelCase audioUrl" do
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_file)
      expect(SpeechService::Client).not_to receive(:speech_to_text_from_url)

      post "/v1/speech/stt",
           params: { audioUrl: "https://cdn.example.com/audio.wav" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "surfaces provider failures as a server error" do
      allow(SpeechService::Client).to receive(:speech_to_text_from_url)
        .and_return(error: "Speech service is unavailable")

      post "/v1/speech/stt",
           params: { audio_url: "https://cdn.example.com/audio.wav" },
           headers: headers,
           as: :json

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
