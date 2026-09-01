module MessageService
  class Speech < Base
    TEXT_REQUIRED = "speech.text_required"
    TEXT_PARAMETER_MISSING = "speech.text_parameter_missing"
    AUDIO_REQUIRED = "speech.audio_required"
    AUDIO_PARAMETER_MISSING = "speech.audio_parameter_missing"
    MESSAGE_REQUIRED = "speech.message_required"
    MESSAGE_PARAMETER_MISSING = "speech.message_parameter_missing"
    MESSAGE_NOT_FOUND = "speech.message_not_found"
    GENERATED = "speech.generated"
    TRANSCRIBED = "speech.transcribed"
    TTS_QUEUED = "speech.tts_queued"
    TTS_READY = "speech.tts_ready"
    TTS_FAILED = "speech.tts_failed"
    QUEUE_FAILED = "speech.queue_failed"
    SERVICE_ERROR = "speech.service_error"
    PROVIDER_ERROR = "speech.provider_error"
    LIVE_NOT_CONFIGURED = "speech.live_not_configured"
  end
end
