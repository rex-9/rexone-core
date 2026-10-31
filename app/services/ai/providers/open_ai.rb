# frozen_string_literal: true

module Ai
  module Providers
    class OpenAi < Base
      protected

      def provider_name
        "OpenAI"
      end

      def api_key
        AppConfig::OPENAI_API_KEY
      end

      def base_url
        AppConfig::OPENAI_BASE_URL
      end

      def default_model
        AppConfig::OPENAI_MODEL
      end
    end
  end
end
