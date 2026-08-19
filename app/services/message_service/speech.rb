module MessageService
  class Speech < Base
    TEXT_REQUIRED = "speech.text_required"
    TEXT_PARAMETER_MISSING = "speech.text_parameter_missing"
    GENERATED = "speech.generated"
    SERVICE_ERROR = "speech.service_error"
    PROVIDER_ERROR = "speech.provider_error"
  end
end
