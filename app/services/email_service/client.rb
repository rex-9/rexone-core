# app/services/email_service/client.rb

module EmailService
  class Client
    class << self
      delegate :send_email,
               :send_template,
               to: :provider

      private

      def provider
        case AppConfig::EMAIL_PROVIDER.to_sym
        when :brevo
          Brevo.new
        when :one_signal
          OneSignal.new
        else
          raise Error, "Unknown email provider: #{AppConfig::EMAIL_PROVIDER}"
        end
      end
    end
  end
end
