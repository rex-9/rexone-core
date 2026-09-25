# frozen_string_literal: true

# app/services/ai/providers/client.rb

module Ai
  module Providers
    class Client
      class << self
        def chat(**kwargs)
          provider_name = kwargs.delete(:provider)
          kwargs[:messages] = Ai::ToonService.prepare_messages_for_llm(kwargs[:messages]) if kwargs[:messages].present?
          provider(provider_name).chat(**kwargs)
        end

        def stream_chat(**kwargs, &block)
          provider_name = kwargs.delete(:provider)
          kwargs[:messages] = Ai::ToonService.prepare_messages_for_llm(kwargs[:messages]) if kwargs[:messages].present?
          provider(provider_name).stream_chat(**kwargs, &block)
        end

        def for_provider(name)
          provider(name)
        end

        def reset_providers!
          @gemini = nil
          @deepseek = nil
        end

        private

        def provider(name = nil)
          case name.to_s.downcase
          when AiConstants::Provider::GEMINI
            @gemini ||= Gemini.new
          else
            @deepseek ||= DeepSeek.new
          end
        end
      end
    end
  end
end
