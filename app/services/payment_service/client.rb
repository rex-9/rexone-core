# app/services/payment_service/client.rb
module PaymentService
  class Client
    class << self
      delegate :create_checkout_session,
               :get_session,
               :cancel_subscription,
               :pause_subscription,
               :resume_subscription,
               :get_subscription,
               :refund_payment,
               :create_product,
               :update_product,
               :handle_webhook,
               to: :provider

      private

      def provider
        @provider ||= Stripe.new
      end
    end
  end
end
