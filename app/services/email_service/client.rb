# app/services/email_service/client.rb

module EmailService
  class Client
    class << self
      delegate :send_email,
               :send_template,
               to: :provider

      private

      def provider
        @provider ||= OneSignal.new
      end
    end
  end
end
