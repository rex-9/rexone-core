# frozen_string_literal: true

# app/services/ai/providers/client.rb

module Ai
  module Providers
    class Client
      class << self
        def chat(provider:, **kwargs)
          kwargs[:messages] = Ai::ToonService.prepare_messages_for_llm(kwargs[:messages]) if kwargs[:messages].present?
          provider(provider).chat(**kwargs)
        end

        def stream_chat(provider:, **kwargs, &block)
          kwargs[:messages] = Ai::ToonService.prepare_messages_for_llm(kwargs[:messages]) if kwargs[:messages].present?
          provider(provider).stream_chat(**kwargs, &block)
        end

        def for_provider(name)
          provider(name)
        end

        def reset_providers!
          @gemini = nil
          @deepseek = nil
        end

        private

        def provider(name)
          case name.to_s.downcase
          when AiConstants::Provider::GEMINI
            @gemini ||= Gemini.new
          when AiConstants::Provider::DEEPSEEK
            @deepseek ||= DeepSeek.new
          else
            raise ArgumentError, "Unsupported AI provider: #{name.inspect}"
          end
        end
      end
    end
  end
end
