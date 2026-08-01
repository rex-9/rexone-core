# app/services/ai_service/client.rb

module AiService
  class Client
    class << self
      delegate :chat,
               :stream_chat,
               to: :provider

      private

      def provider
        @provider ||= DeepSeek.new
      end
    end
  end
end
