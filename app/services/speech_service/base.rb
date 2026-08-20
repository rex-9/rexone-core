# app/services/speech_service/base.rb

module SpeechService
  class Base
    def text_to_speech(text:, voice_name: nil)
      raise NotImplementedError, "#{self.class} must implement #text_to_speech"
    end

    def speech_to_text_with_url(audioUrl:)
      raise NotImplementedError, "#{self.class} must implement #speech_to_text_with_url"
    end
  end
end
