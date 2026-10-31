# frozen_string_literal: true

module Ai
  module Providers
    class Gemini < Base
      protected

      def provider_name
        "Gemini"
      end

      def api_key
        AppConfig::GEMINI_API_KEY
      end

      def base_url
        AppConfig::GEMINI_BASE_URL
      end

      def default_model
        AppConfig::GEMINI_MODEL
      end
    end
  end
end
