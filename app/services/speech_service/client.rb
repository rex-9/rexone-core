# app/services/speech_service/client.rb

module SpeechService
  class Client
    class << self
      delegate :text_to_speech,
               to: :provider

      private

      def provider
        @provider ||= NovaSpeech.new
      end
    end
  end
end
