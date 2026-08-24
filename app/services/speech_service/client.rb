# app/services/speech_service/client.rb

module SpeechService
  class Client
    class << self
      delegate :text_to_speech,
               :speech_to_text_from_file,
               :speech_to_text_from_url,
               to: :provider

      private

      def provider
        @provider ||= NovaSpeech.new
      end
    end
  end
end
