# app/services/speech_service/client.rb

module SpeechService
  class Client
    class << self
      delegate :speech_to_text_from_file,
               :speech_to_text_from_url,
               to: :provider

      delegate :text_to_speech,
               :start_live_stt,
               to: :azure_provider

      private

      def provider
        @provider ||= NovaSpeech.new
      end

      def azure_provider
        @azure_provider ||= AzureSpeech.new
      end
    end
  end
end
