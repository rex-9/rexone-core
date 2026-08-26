# app/services/speech_service/azure_speech.rb

module SpeechService
  class AzureSpeech < Base
    LOG_PREFIX = "[AzureSpeech]".freeze

    def text_to_speech(text:, voice_name: nil)
      raise NotImplementedError, "#{self.class} does not implement TTS"
    end

    def speech_to_text_from_file(audio:)
      raise NotImplementedError, "#{self.class} does not implement file STT"
    end

    def speech_to_text_from_url(audio_url:)
      raise NotImplementedError, "#{self.class} does not implement URL STT"
    end

    def start_live_stt(language: nil, on_event:, socket: nil)
      Session.new(
        language: language.presence || AppConfig::AZURE_SPEECH_LANGUAGE,
        on_event: on_event,
        socket: socket
      ).tap(&:start)
    end
  end
end
