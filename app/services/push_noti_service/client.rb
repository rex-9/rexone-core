# app/services/push_noti_service/client.rb

module PushNotiService
  class Client
    class << self
      delegate :send_to_device,
               :send_to_user,
               :send_to_segment,
               to: :provider

      private

      def provider
        @provider ||= OneSignal.new
      end
    end
  end
end
