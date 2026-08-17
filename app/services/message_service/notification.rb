module MessageService
  class Notification < Base
    QUEUED = "notification.queued"
    QUEUE_FAILED = "notification.queue_failed"
    INVALID_REQUEST = "notification.invalid_request"
    TITLE_REQUIRED = "notification.title_required"
    MESSAGE_REQUIRED = "notification.message_required"
    CHANNEL_REQUIRED = "notification.channel_required"
    INVALID_CHANNEL = "notification.invalid_channel"
    INVALID_AUDIENCE = "notification.invalid_audience"
    ROLE_IDS_REQUIRED = "notification.role_ids_required"
    INVALID_DATA = "notification.invalid_data"
    NO_RECIPIENTS = "notification.no_recipients"
    DEFAULT_TITLE = "notification.default_title"
    DEFAULT_BODY = "notification.default_body"
    TEMPLATE_NOT_FOUND = "notification.template_not_found"
    WELCOME_TITLE = "notification.welcome.title"
    WELCOME_BODY = "notification.welcome.body"
    SIGN_IN_ALERT_TITLE = "notification.sign_in_alert.title"
    SIGN_IN_ALERT_BODY = "notification.sign_in_alert.body"
  end
end
