# app/services/socket_service/client.rb

module SocketService
  class Client
    class << self
      delegate :broadcast,
               :broadcast_to_channel,
               to: :provider

      private

      def provider
        @provider ||= ActionCable.new
      end
    end
  end
end
