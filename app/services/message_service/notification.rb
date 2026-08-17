module MessageService
  class Notification < Base
    INVALID_PUSH_TYPE = "notification.invalid_push_type"
    INVALID_EMAIL_TYPE = "notification.invalid_email_type"
    SUPPORTED_TYPES = "notification.supported_types"
    PUSH_QUEUED = "notification.push_queued"
    PUSH_FAILED = "notification.push_failed"
    EMAIL_QUEUED = "notification.email_queued"
    EMAIL_FAILED = "notification.email_failed"
    DEFAULT_TITLE = "notification.default_title"
    DEFAULT_BODY = "notification.default_body"
    TEMPLATE_NOT_FOUND = "notification.template_not_found"
    WELCOME_TITLE = "notification.welcome.title"
    WELCOME_BODY = "notification.welcome.body"
    SIGN_IN_ALERT_TITLE = "notification.sign_in_alert.title"
    SIGN_IN_ALERT_BODY = "notification.sign_in_alert.body"
  end
end
