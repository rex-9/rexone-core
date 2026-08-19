# app/services/speech_service/base.rb

module SpeechService
  class Base
    def text_to_speech(text:, voice_name: nil)
      raise NotImplementedError, "#{self.class} must implement #text_to_speech"
    end
  end
end
