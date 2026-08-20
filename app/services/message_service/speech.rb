module MessageService
  class Speech < Base
    TEXT_REQUIRED = "speech.text_required"
    TEXT_PARAMETER_MISSING = "speech.text_parameter_missing"
    AUDIO_URL_REQUIRED = "speech.audio_url_required"
    AUDIO_URL_PARAMETER_MISSING = "speech.audio_url_parameter_missing"
    GENERATED = "speech.generated"
    TRANSCRIBED = "speech.transcribed"
    SERVICE_ERROR = "speech.service_error"
    PROVIDER_ERROR = "speech.provider_error"
  end
end
