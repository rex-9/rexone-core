# app/controllers/v1/speech_controller.rb
class V1::SpeechController < V1::ApplicationController
  # POST /speech/tts
  def create_tts
    text = params[:text]

    if text.blank?
      render_json_response(
        status_code: 422,
        message: speech_message(MessageService::Speech::TEXT_REQUIRED),
        error: speech_message(MessageService::Speech::TEXT_PARAMETER_MISSING)
      )
      return
    end

    result = SpeechService::Client.text_to_speech(
      text: text,
      voice_name: params[:voiceName].presence
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: speech_message(MessageService::Speech::SERVICE_ERROR),
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: speech_message(MessageService::Speech::GENERATED),
        data: result
      )
    end
  end

  # POST /speech/stt-url
  def create_stt_url
    audioUrl = params[:audioUrl]

    if audioUrl.blank?
      render_json_response(
        status_code: 422,
        message: speech_message(MessageService::Speech::AUDIO_URL_REQUIRED),
        error: speech_message(MessageService::Speech::AUDIO_URL_PARAMETER_MISSING)
      )
      return
    end

    result = SpeechService::Client.speech_to_text_with_url(audioUrl: audioUrl)

    if result[:error]
      render_json_response(
        status_code: 500,
        message: speech_message(MessageService::Speech::SERVICE_ERROR),
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: speech_message(MessageService::Speech::TRANSCRIBED),
        data: { text: result[:text] }
      )
    end
  end

  private

  def speech_message(key, **options)
    MessageService::Speech.t(key, **options)
  end
end
