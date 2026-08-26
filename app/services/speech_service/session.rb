# app/services/speech_service/session.rb

require "json"
require "securerandom"
require "uri"

module SpeechService
  class Session
      def initialize(language:, on_event:, socket: nil)
        @language = language
        @on_event = on_event
        @socket = socket
        @connection_id = SecureRandom.uuid.delete("-")
        @request_id = SecureRandom.uuid.delete("-")
        @mutex = Mutex.new
        @stopped = false
        @open = !socket.nil?
        @pending_frames = []
        @riff_sent = false
        @last_audio_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def start
        if AppConfig::AZURE_SPEECH_KEY.blank? && @socket.nil?
          emit_error(MessageService::Speech.t(MessageService::Speech::LIVE_NOT_CONFIGURED))
          @stopped = true
          return self
        end

        @socket ||= open_socket
        send_speech_config
        self
      rescue LoadError => e
        Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Start Error: #{e.message}")
        emit_error(MessageService::Speech.t(MessageService::Speech::LIVE_NOT_CONFIGURED))
        @stopped = true
        self
      rescue => e
        Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Start Error: #{e.message}")
        emit_error(provider_error_message)
        @stopped = true
        self
      end

      def write_audio(bytes)
        return if @stopped || @socket.nil? || bytes.blank?

        @last_audio_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        audio_chunks(bytes.to_s.b).each { |chunk| deliver(audio_frame(chunk), type: :binary) }
      rescue => e
        Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Write Error: #{e.message}")
        emit_error(provider_error_message)
        stop
      end

      def idle?
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_audio_at
        elapsed >= SpeechConstants::Live::IDLE_TIMEOUT_SECONDS
      end

      def stop
        return if @stopped

        end_audio_stream
        @stopped = true
        @socket&.close
      rescue => e
        Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Close Error: #{e.message}")
      end

      # Azure drops frames sent before the handshake completes, so anything
      # queued during connect is flushed here.
      def mark_open
        @mutex.synchronize do
          @open = true
          return if @stopped || @socket.nil?

          @pending_frames.each { |data, type| @socket.send(data, type: type) }
          @pending_frames.clear
        end
      end

      def handle_raw_message(payload)
        path, body = parse_message(payload)
        return if path.blank?

        case path
        when SpeechConstants::Live::PATH_HYPOTHESIS
          text = json_text(body, "Text")
          emit(type: SpeechConstants::Live::TYPE_PARTIAL, text: text) if text.present?
        when SpeechConstants::Live::PATH_PHRASE
          text = json_text(body, "DisplayText") || json_text(body, "Text")
          emit(type: SpeechConstants::Live::TYPE_FINAL, text: text) if text.present?
        end
      rescue JSON::ParserError => e
        Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Parse Error: #{e.message}")
      end

      private

      def open_socket
        require "websocket-client-simple"

        uri = websocket_uri
        on_open = method(:mark_open)
        on_message = method(:handle_raw_message)
        on_socket_error = lambda do |error|
          Rails.logger.error("#{SpeechService::AzureSpeech::LOG_PREFIX} Socket Error: #{error}")
          emit_error(provider_error_message)
        end

        socket = WebSocket::Client::Simple.connect(
          uri.to_s,
          headers: {
            SpeechConstants::Live::HEADER_SUBSCRIPTION_KEY => AppConfig::AZURE_SPEECH_KEY,
            SpeechConstants::Live::HEADER_CONNECTION_ID => @connection_id
          }
        )
        # websocket-client-simple instance_execs these blocks on the client.
        socket.on(:open) { on_open.call }
        socket.on(:message) { |message| on_message.call(message.data.to_s) }
        socket.on(:error) { |error| on_socket_error.call(error) }
        socket
      end

      def websocket_uri
        query = URI.encode_www_form(
          language: @language,
          format: SpeechConstants::Live::FORMAT
        )

        URI.parse(
          "wss://#{AppConfig::AZURE_SPEECH_REGION}.stt.speech.microsoft.com" \
          "#{SpeechConstants::Live::RECOGNITION_PATH}?#{query}"
        )
      end

      def send_speech_config
        payload = {
          context: {
            system: { name: "rexone-core", version: "1.0.0",},
            os: { platform: "Mac", name: "rexone-core", version: "" }
          }
        }.to_json

        # speech.config carries no X-RequestId; it is not tied to one request.
        frame = text_frame(
          SpeechConstants::Live::PATH_SPEECH_CONFIG,
          SpeechConstants::Live::CONFIG_CONTENT_TYPE,
          payload,
          request_id: false
        )
        deliver(frame, type: :text)
      end

      # A zero-length audio message tells Azure the turn is finished.
      def end_audio_stream
        deliver(audio_frame(""), type: :binary) if @open && @riff_sent
      end

      def deliver(data, type:)
        @mutex.synchronize do
          return if @stopped || @socket.nil?

          if @open
            @socket.send(data, type: type)
          else
            @pending_frames << [ data, type ]
          end
        end
      end

      def header_lines(path, content_type, request_id: true)
        lines = [ "Path: #{path}" ]
        lines << "X-RequestId: #{@request_id}" if request_id
        lines << "X-Timestamp: #{Time.now.utc.iso8601(3)}"
        lines << "Content-Type: #{content_type}"
        lines
      end

      def text_frame(path, content_type, body, request_id: true)
        "#{header_lines(path, content_type, request_id: request_id).join("\r\n")}\r\n\r\n#{body}"
      end

      # Binary messages prefix the header block with its big-endian 16-bit size.
      def audio_frame(body)
        headers = header_lines(
          SpeechConstants::Live::PATH_AUDIO,
          SpeechConstants::Live::AUDIO_CONTENT_TYPE
        ).join("\r\n").b

        [ headers.bytesize ].pack("n") + headers + body.to_s.b
      end

      def audio_chunks(pcm)
        payload = @riff_sent ? pcm : riff_header + pcm
        @riff_sent = true

        chunks = []
        offset = 0
        while offset < payload.bytesize
          chunks << payload.byteslice(offset, SpeechConstants::Live::MAX_AUDIO_CHUNK_BYTES)
          offset += SpeechConstants::Live::MAX_AUDIO_CHUNK_BYTES
        end
        chunks
      end

      # Azure terminates the connection unless the first audio chunk of a turn
      # opens with a valid RIFF header.
      def riff_header
        channels = SpeechConstants::Live::AUDIO_CHANNELS
        sample_rate = SpeechConstants::Live::AUDIO_SAMPLE_RATE
        bits = SpeechConstants::Live::AUDIO_BITS_PER_SAMPLE
        block_align = channels * bits / 8
        size = SpeechConstants::Live::RIFF_STREAM_SIZE

        [
          "RIFF", size, "WAVE",
          "fmt ", 16, 1, channels, sample_rate, sample_rate * block_align, block_align, bits,
          "data", size
        ].pack("a4Va4a4VvvVVvva4V")
      end

      def parse_message(payload)
        text = payload.to_s
        header_sep = "\r\n\r\n"
        sep_index = text.index(header_sep)
        return [ nil, nil ] unless sep_index

        headers = text[0, sep_index]
        body = text[(sep_index + header_sep.length)..]
        path = headers[/^Path:\s*(.+)$/i, 1]&.strip
        [ path, body ]
      end

      def json_text(body, key)
        return if body.blank?

        JSON.parse(body)[key].presence
      end

      def emit(event)
        @on_event.call(event)
      end

      def emit_error(message)
        emit(type: SpeechConstants::Live::TYPE_ERROR, error: message)
      end

      def provider_error_message
        MessageService::Speech.t(MessageService::Speech::PROVIDER_ERROR)
      end
  end
end
