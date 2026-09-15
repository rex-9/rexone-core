# frozen_string_literal: true

# app/services/ai/providers/base.rb
module Ai
  module Providers
    class Base
      def chat(messages:, model: nil, temperature: nil, max_tokens: nil, timeout_seconds: nil)
        raise NotImplementedError, "#{self.class} must implement #chat"
      end

      def stream_chat(messages:, model: nil, temperature: nil, max_tokens: nil, timeout_seconds: nil, &block)
        raise NotImplementedError, "#{self.class} must implement #stream_chat"
      end
    end
  end
end
