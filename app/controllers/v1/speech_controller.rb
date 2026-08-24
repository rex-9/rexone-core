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
      voice_name: params[:voice_name].presence
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: speech_message(MessageService::Speech::SERVICE_ERROR),
        error: result[:error]
      )
    else
      send_data result[:bytes],
        type: result[:content_type],
        filename: result[:filename],
        disposition: "inline"
    end
  end

  # POST /speech/stt
  def create_stt
    audio = params[:audio]
    audio_url = params[:audio_url]

    if audio.present?
      result = SpeechService::Client.speech_to_text_from_file(audio: audio)
    elsif audio_url.present?
      result = SpeechService::Client.speech_to_text_from_url(audio_url: audio_url)
    else
      render_json_response(
        status_code: 422,
        message: speech_message(MessageService::Speech::AUDIO_REQUIRED),
        error: speech_message(MessageService::Speech::AUDIO_PARAMETER_MISSING)
      )
      return
    end

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
