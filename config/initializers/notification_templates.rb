# config/initializers/notification_templates.rb
module PushNotiTemplates
  WELCOME = "welcome".freeze
  SIGN_IN_ALERT = "sign_in_alert".freeze
  CUSTOM = "custom".freeze

  ALL = [ WELCOME, SIGN_IN_ALERT, CUSTOM ].freeze
end

module MailTemplates
  CONFIRMATION = "confirmation".freeze
  PASSWORD_RESET = "password_reset".freeze
  CUSTOM = "custom".freeze

  ALL = [ CONFIRMATION, PASSWORD_RESET, CUSTOM ].freeze
end
