# frozen_string_literal: true

module Ai
  module Providers
    class Anthropic < Base
      protected

      def provider_name
        "Anthropic"
      end

      def api_key
        AppConfig::ANTHROPIC_API_KEY
      end

      def base_url
        AppConfig::ANTHROPIC_BASE_URL
      end

      def default_model
        AppConfig::ANTHROPIC_MODEL
      end
    end
  end
end
