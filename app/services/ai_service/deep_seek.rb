# app/services/ai_service/deepseek.rb

require "net/http"
require "json"
require "uri"

module AiService
  class DeepSeek < Base
    def initialize
      @api_key = ENV.fetch("DEEPSEEK_API_KEY")
      @base_url = ENV.fetch("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
      @default_model = ENV.fetch("DEEPSEEK_MODEL", "deepseek-chat")
    end

    def chat(messages:, model: nil, temperature: 0.7, max_tokens: 2000)
      payload = {
        model: model || @default_model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        stream: false
      }

      # DeepSeek specific: enable thinking for better reasoning
      # payload[:thinking] = { type: "enabled" }

      uri = URI.parse("#{@base_url}/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = payload.to_json

      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.error("[DeepSeek] API Error: #{response.body}")
        { error: "API error: #{response.code}" }
      end
    rescue => e
      Rails.logger.error("[DeepSeek] Error: #{e.message}")
      { error: e.message }
    end

    def stream_chat(messages:, model: nil, temperature: 0.7, max_tokens: 2000, &block)
      payload = {
        model: model || @default_model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        stream: true
      }

      # For streaming, thinking can be enabled
      # payload[:thinking] = { type: "enabled" }

      uri = URI.parse("#{@base_url}/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri.path)
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
              # Skip invalid JSON
            end
          end
        end
      end
    rescue => e
      Rails.logger.error("[DeepSeek] Stream Error: #{e.message}")
      yield nil
    end
  end

  class Error < StandardError; end
end
