# app/services/push_noti_service/base.rb
module PushNotiService
  class Base
    def send_to_device(subscription_id:, title:, body:, data: {}, sound: nil)
      raise NotImplementedError, "#{self.class} must implement #send_to_device"
    end

    def send_to_user(user_id:, title:, body:, data: {}, sound: nil)
      raise NotImplementedError, "#{self.class} must implement #send_to_user"
    end

    def send_to_segment(segment:, title:, body:, data: {}, sound: nil)
      raise NotImplementedError, "#{self.class} must implement #send_to_segment"
    end
  end
end
