# app/services/speech_service/nova_speech.rb

require "net/http"
require "json"
require "uri"

module SpeechService
  class NovaSpeech < Base
    LOG_PREFIX = "[NovaSpeech]".freeze
    READ_TIMEOUT_SECONDS = 120
    OPEN_TIMEOUT_SECONDS = 20

    def initialize
      @base_url = AppConfig::SPEECH_SERVICE_BASE_URL.to_s.chomp("/")
    end

    def text_to_speech(text:, voice_name: nil)
      payload = { "text" => text }
      payload["voiceName"] = voice_name if voice_name.present?

      map_tts_success(post_json(AppConfig::SPEECH_TTS_ENDPOINT_PATH, payload))
    end

    def speech_to_text_with_url(audioUrl:)
      payload = { "audioUrl" => audioUrl }

      map_stt_success(post_json(AppConfig::SPEECH_STT_URL_ENDPOINT_PATH, payload))
    end

    private

    def post_json(path, payload)
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT_SECONDS
      http.read_timeout = READ_TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.error("#{LOG_PREFIX} API Error: #{response.body}")
        { error: provider_error_message }
      end
    rescue JSON::ParserError => e
      Rails.logger.error("#{LOG_PREFIX} Parse Error: #{e.message}")
      { error: provider_error_message }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Error: #{e.message}")
      { error: provider_error_message }
    end

    def map_tts_success(body)
      return body if body[:error]

      Rails.logger.info("#{LOG_PREFIX} TTS Success: #{body}")
      audio_payload = body["audio"] || {}
      visemes_payload = body["visemes"] || []

      {
        audio: {
          data: audio_payload["data"],
          format: audio_payload["format"],
          sample_rate: audio_payload["sampleRate"]
        },
        visemes: visemes_payload.map { |viseme| map_viseme(viseme) }
      }
    end

 

    def map_viseme(viseme)
      {
        audio_offset: viseme["audioOffset"],
        viseme_id: viseme["visemeId"],
        audio_offset_ms: viseme["audioOffsetMs"]
      }
    end

    def map_stt_success(body)
      return body if body[:error]

      Rails.logger.info("#{LOG_PREFIX} STT Success: #{body}")

      { text: body["data"]["text"].to_s }
    end

    def provider_error_message
      MessageService::Speech.t(MessageService::Speech::PROVIDER_ERROR)
    end
  end
end
