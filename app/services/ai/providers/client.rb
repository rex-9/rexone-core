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
          @providers = {}
        end

        private

        def provider(name)
          key = name.to_s.downcase
          klass = AiConstants::Provider::CONFIG.dig(key, :client)
          raise ArgumentError, "Unsupported AI provider: #{name.inspect}" unless klass

          @providers ||= {}
          @providers[key] ||= klass.new
        end
      end
    end
  end
end
