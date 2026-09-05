# app/services/socket_service/base.rb

module SocketService
  class Base
    def broadcast(user_id:, message:, data: {}, **extra)
      raise NotImplementedError, "#{self.class} must implement #broadcast"
    end

    def broadcast_to_channel(channel:, message:, data: {})
      raise NotImplementedError, "#{self.class} must implement #broadcast_to_channel"
    end
  end
end
