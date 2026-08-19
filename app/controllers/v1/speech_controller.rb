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

  private

  def speech_message(key, **options)
    MessageService::Speech.t(key, **options)
  end
end
