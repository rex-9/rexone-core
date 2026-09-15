# frozen_string_literal: true

# app/services/ai/providers/gemini.rb

require "net/http"
require "json"
require "uri"

module Ai
  module Providers
    class Gemini < Base
      LOG_PREFIX = "[Gemini]".freeze

      def initialize
        @api_key = AppConfig::GEMINI_API_KEY
        @base_url = AppConfig::GEMINI_BASE_URL
        @default_model = AppConfig::GEMINI_MODEL
      end

      def chat(messages:, model: nil, temperature: 0.7, max_tokens: 2000, timeout_seconds: nil)
        payload = {
          model: model || @default_model,
          messages: messages,
          temperature: temperature,
          max_tokens: max_tokens,
          stream: false
        }

        uri = URI.parse("#{@base_url}/chat/completions")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout_seconds if timeout_seconds.present?
        http.read_timeout = timeout_seconds if timeout_seconds.present?

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}"
        request.body = payload.to_json

        response = http.request(request)

        if response.code.to_i == 200
          JSON.parse(response.body)
        else
          Rails.logger.error("#{LOG_PREFIX} API Error (#{response.code}): #{response.body}")
          { error: provider_error_message }
        end
      rescue => e
        Rails.logger.error("#{LOG_PREFIX} Error: #{e.message}")
        { error: provider_error_message }
      end

      def stream_chat(messages:, model: nil, temperature: 0.7, max_tokens: 2000, timeout_seconds: nil, &block)
        payload = {
          model: model || @default_model,
          messages: messages,
          temperature: temperature,
          max_tokens: max_tokens,
          stream: true
        }

        uri = URI.parse("#{@base_url}/chat/completions")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout_seconds if timeout_seconds.present?
        http.read_timeout = timeout_seconds if timeout_seconds.present?

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}"
        request.body = payload.to_json

        http.request(request) do |response|
          response.read_body do |chunk|
            chunk.to_s.each_line do |line|
              next unless line.start_with?("data: ")
              data = line.sub("data: ", "").strip
              next if data == "[DONE]"

              begin
                parsed = JSON.parse(data)
                content = parsed.dig("choices", 0, "delta", "content")
                yield content if content.present?
              rescue JSON::ParserError
                # Skip invalid chunk JSON
              end
            end
          end
        end
      rescue => e
        Rails.logger.error("#{LOG_PREFIX} Stream Error: #{e.message}")
        yield nil
      end

      private

      def provider_error_message
        MessageService::Ai.t(MessageService::Ai::PROVIDER_ERROR)
      end
    end
  end
end
