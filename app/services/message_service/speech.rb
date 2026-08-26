module MessageService
  class Speech < Base
    TEXT_REQUIRED = "speech.text_required"
    TEXT_PARAMETER_MISSING = "speech.text_parameter_missing"
    AUDIO_REQUIRED = "speech.audio_required"
    AUDIO_PARAMETER_MISSING = "speech.audio_parameter_missing"
    GENERATED = "speech.generated"
    TRANSCRIBED = "speech.transcribed"
    SERVICE_ERROR = "speech.service_error"
    PROVIDER_ERROR = "speech.provider_error"
    LIVE_NOT_CONFIGURED = "speech.live_not_configured"
  end
end
