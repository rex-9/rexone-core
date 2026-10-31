# frozen_string_literal: true

module Ai
  module Providers
    class DeepSeek < Base
      protected

      def provider_name
        "DeepSeek"
      end

      def api_key
        AppConfig::DEEPSEEK_API_KEY
      end

      def base_url
        AppConfig::DEEPSEEK_BASE_URL
      end

      def default_model
        AppConfig::DEEPSEEK_MODEL
      end
    end
  end
end
