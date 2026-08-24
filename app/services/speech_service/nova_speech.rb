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
      payload = { SpeechConstants::Tts::TEXT => text }
      payload[SpeechConstants::Tts::VOICE_NAME] = voice_name if voice_name.present?
      payload[SpeechConstants::Tts::RETURN_FILE] = true

      map_tts(
        request_http(AppConfig::SPEECH_TTS_ENDPOINT_PATH, parse_json: false) do |request|
          request["Content-Type"] = "application/json"
          request.body = payload.to_json
        end
      )
    end

    def speech_to_text_from_file(audio:)
      map_stt(post_multipart(AppConfig::SPEECH_STT_ENDPOINT_PATH, audio: audio))
    end

    def speech_to_text_from_url(audio_url:)
      payload = { SpeechConstants::Stt::AUDIO_URL => audio_url }

      map_stt(post_json(AppConfig::SPEECH_STT_ENDPOINT_PATH, payload))
    end

    private

    def post_json(path, payload)
      request_http(path) do |request|
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
      end
    end

    def post_multipart(path, audio:)
      file = audio.respond_to?(:tempfile) ? audio.tempfile : audio
      filename = audio.respond_to?(:original_filename) ? audio.original_filename : File.basename(file.path)
      content_type = audio.respond_to?(:content_type) ? audio.content_type.to_s : "application/octet-stream"
      content_type = "application/octet-stream" if content_type.blank?

      request_http(path) do |request|
        file.rewind if file.respond_to?(:rewind)
        request.set_form(
          [ [ SpeechConstants::Stt::AUDIO, file, { filename: filename, content_type: content_type } ] ],
          "multipart/form-data"
        )
      end
    end

    def request_http(path, parse_json: true)
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT_SECONDS
      http.read_timeout = READ_TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      yield request
      response = http.request(request)

      if response.code.to_i == 200
        return response unless parse_json

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

    def map_tts(response)
      return response if response.is_a?(Hash) && response[:error]

      part = extract_multipart_part(response, name: SpeechConstants::Tts::AUDIO)
      if part.nil? || part[:bytes].blank?
        Rails.logger.error("#{LOG_PREFIX} Missing audio part in TTS response")
        return { error: provider_error_message }
      end

      Rails.logger.info("#{LOG_PREFIX} TTS file received: #{part[:filename]}")

      {
        bytes: part[:bytes],
        content_type: part[:content_type].presence || SpeechConstants::Tts::CONTENT_TYPE,
        filename: part[:filename].presence || SpeechConstants::Tts::FILENAME
      }
    end

    def extract_multipart_part(response, name:)
      boundary = response["Content-Type"].to_s[/boundary="?([^";]+)"?/, 1]
      return if boundary.blank?

      header_sep = "\r\n\r\n".b
      delimiter = "--#{boundary}".b

      response.body.to_s.b.split(delimiter).each do |part|
        next if part.blank? || part.strip == "--".b || part.start_with?("--".b)

        sep_index = part.index(header_sep)
        next unless sep_index

        headers = part[0, sep_index].to_s
        next unless headers.match?(/Content-Disposition:.*\bname="#{Regexp.escape(name)}"/i)

        bytes = part[(sep_index + header_sep.bytesize)..]
        bytes = bytes.sub(/\r\n\z/, "".b)

        return {
          bytes: bytes,
          filename: headers[/filename="([^"]+)"/, 1],
          content_type: headers[/Content-Type:\s*([^\r\n]+)/i, 1]&.strip
        }
      end

      nil
    end

    def map_stt(body)
      return body if body[:error]

      Rails.logger.info("#{LOG_PREFIX} STT Success: #{body}")

      { text: body["data"]["text"].to_s }
    end

    def provider_error_message
      MessageService::Speech.t(MessageService::Speech::PROVIDER_ERROR)
    end
  end
end
