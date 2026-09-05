# app/constants/notification_constants/audience_type.rb

module NotificationConstants
  module AudienceType
    ALL       = "all".freeze
    ROLES     = "roles".freeze
    USERS     = "users".freeze
    AUDIENCES = [ ALL, ROLES, USERS ].freeze
  end
end
