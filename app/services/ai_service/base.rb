# app/services/ai_service/base.rb

module AiService
  class Base
    def chat(messages:, model: nil, temperature: nil, max_tokens: nil)
      raise NotImplementedError, "#{self.class} must implement #chat"
    end

    def stream_chat(messages:, model: nil, temperature: nil, max_tokens: nil, &block)
      raise NotImplementedError, "#{self.class} must implement #stream_chat"
    end
  end
end
