# app/services/speech_service/base.rb

module SpeechService
  class Base
    def text_to_speech(text:, voice_name: nil)
      raise NotImplementedError, "#{self.class} must implement #text_to_speech"
    end

    def speech_to_text_from_file(audio:)
      raise NotImplementedError, "#{self.class} must implement #speech_to_text_from_file"
    end

    def speech_to_text_from_url(audio_url:)
      raise NotImplementedError, "#{self.class} must implement #speech_to_text_from_url"
    end

    def start_live_stt(language: nil, on_event:, socket: nil)
      raise NotImplementedError, "#{self.class} must implement #start_live_stt"
    end
  end
end
