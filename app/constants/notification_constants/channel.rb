# app/constants/notification_constants/channel.rb

module NotificationConstants
  module Channel
    SOCKET   = "socket".freeze
    PUSH     = "push".freeze
    EMAIL    = "email".freeze
    CHANNELS = [ SOCKET, PUSH, EMAIL ].freeze
    ALL      = CHANNELS
  end
end
