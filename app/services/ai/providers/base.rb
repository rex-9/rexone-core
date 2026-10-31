# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Ai
  module Providers
    class Error < StandardError; end

    class Base
      def chat(messages:, model: nil, temperature: nil, max_tokens: nil, timeout_seconds: nil)
        uri = chat_uri
        http = build_http(uri, timeout_seconds)
        request = build_post_request(uri)
        request.body = {
          model: model.presence || default_model,
          messages: messages,
          temperature: temperature || AiConstants::Defaults::TEMPERATURE,
          max_tokens: max_tokens || AiConstants::Defaults::MAX_OUTPUT_TOKENS,
          stream: false
        }.to_json

        response = http.request(request)
        if response.code == "200"
          JSON.parse(response.body)
        else
          message = extract_error_message(response.body) || "HTTP #{response.code}"
          Rails.logger.error("#{log_prefix} Error: #{response.code} - #{response.body}")
          { error: MessageService::Ai.t(MessageService::Ai::PROVIDER_ERROR, details: message) }
        end
      rescue JSON::ParserError => error
        Rails.logger.error("#{log_prefix} JSON Parse Error: #{error.message}")
        { error: MessageService::Ai.t(MessageService::Ai::PROVIDER_ERROR, details: error.message) }
      rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, SocketError => error
        Rails.logger.error("#{log_prefix} Network Error: #{error.message}")
        { error: MessageService::Ai.t(MessageService::Ai::PROVIDER_ERROR, details: error.message) }
      end

      def stream_chat(messages:, model: nil, temperature: nil, max_tokens: nil, timeout_seconds: nil, &block)
        uri = chat_uri
        http = build_http(uri, timeout_seconds)
        request = build_post_request(uri)
        request.body = {
          model: model.presence || default_model,
          messages: messages,
          temperature: temperature || AiConstants::Defaults::TEMPERATURE,
          max_tokens: max_tokens || AiConstants::Defaults::MAX_OUTPUT_TOKENS,
          stream: true
        }.to_json

        http.request(request) do |response|
          response.read_body do |chunk|
            chunk.split("\n").each do |line|
              next unless line.start_with?("data: ")

              data = line.sub("data: ", "").strip
              break if data == "[DONE]"

              begin
                parsed = JSON.parse(data)
                content = parsed.dig("choices", 0, "delta", "content")
                block.call(content) if content
              rescue JSON::ParserError
                # Ignore malformed stream chunks
              end
            end
          end
        end
      rescue StandardError => error
        Rails.logger.error("#{log_prefix} Stream Error: #{error.message}")
        block.call(nil)
      end

      protected

      def provider_name
        raise NotImplementedError
      end

      def api_key
        raise NotImplementedError
      end

      def base_url
        raise NotImplementedError
      end

      def default_model
        raise NotImplementedError
      end

      private

      def log_prefix
        "[#{provider_name}]"
      end

      def chat_uri
        URI("#{base_url.chomp('/')}/chat/completions")
      end

      def build_http(uri, timeout_seconds)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        if timeout_seconds.present?
          http.open_timeout = timeout_seconds
          http.read_timeout = timeout_seconds
        end
        http
      end

      def build_post_request(uri)
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}"
        request
      end

      def extract_error_message(body)
        return nil if body.blank?

        parsed = JSON.parse(body)
        parsed.dig("error", "message") || parsed["message"]
      rescue JSON::ParserError
        nil
      end
    end
  end
end
