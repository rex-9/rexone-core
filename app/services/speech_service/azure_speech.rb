# app/services/speech_service/azure_speech.rb

require "cgi"
require "net/http"
require "uri"

module SpeechService
  class AzureSpeech < Base
    LOG_PREFIX = "[AzureSpeech]".freeze
    READ_TIMEOUT_SECONDS = 120
    OPEN_TIMEOUT_SECONDS = 20

    def text_to_speech(text:, voice_name: nil)
      if AppConfig::AZURE_SPEECH_KEY.blank?
        return { error: provider_error_message }
      end

      voice = voice_name.presence || AppConfig::AZURE_SPEECH_VOICE
      language = AppConfig::AZURE_SPEECH_LANGUAGE
      response = post_ssml(ssml_for(text: text, voice: voice, language: language))
      return response if response.is_a?(Hash) && response[:error]

      {
        bytes: response.body.to_s.b,
        content_type: SpeechConstants::Tts::CONTENT_TYPE,
        filename: SpeechConstants::Tts::FILENAME
      }
    end

    def start_live_stt(language: nil, on_event:, socket: nil)
      Session.new(
        language: language.presence || AppConfig::AZURE_SPEECH_LANGUAGE,
        on_event: on_event,
        socket: socket
      ).tap(&:start)
    end

    private

    def post_ssml(ssml)
      uri = tts_uri
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT_SECONDS
      http.read_timeout = READ_TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      request[SpeechConstants::Live::HEADER_SUBSCRIPTION_KEY] = AppConfig::AZURE_SPEECH_KEY
      request["Content-Type"] = SpeechConstants::Tts::AZURE_SSML_CONTENT_TYPE
      request[SpeechConstants::Tts::HEADER_OUTPUT_FORMAT] = SpeechConstants::Tts::AZURE_OUTPUT_FORMAT
      request[SpeechConstants::Tts::HEADER_USER_AGENT] = SpeechConstants::Tts::AZURE_USER_AGENT
      request.body = ssml

      response = http.request(request)
      return response if response.code.to_i == 200

      Rails.logger.error("#{LOG_PREFIX} TTS API Error: #{response.code} #{response.body}")
      { error: provider_error_message }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} TTS Error: #{e.message}")
      { error: provider_error_message }
    end

    def tts_uri
      URI.parse(
        "https://#{AppConfig::AZURE_SPEECH_REGION}.tts.speech.microsoft.com" \
        "#{SpeechConstants::Tts::AZURE_PATH}"
      )
    end

    def ssml_for(text:, voice:, language:)
      escaped = CGI.escapeHTML(text.to_s)
      <<~SSML
        <speak version="1.0" xml:lang="#{CGI.escapeHTML(language)}">
          <voice name="#{CGI.escapeHTML(voice)}">#{escaped}</voice>
        </speak>
      SSML
    end

    def provider_error_message
      MessageService::Speech.t(MessageService::Speech::PROVIDER_ERROR)
    end
  end
end
