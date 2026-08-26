# app/services/speech_service/client.rb

module SpeechService
  class Client
    class << self
      delegate :text_to_speech,
               :speech_to_text_from_file,
               :speech_to_text_from_url,
               to: :provider

      delegate :start_live_stt, to: :live_provider

      private

      def provider
        @provider ||= NovaSpeech.new
      end

      def live_provider
        @live_provider ||= AzureSpeech.new
      end
    end
  end
end
