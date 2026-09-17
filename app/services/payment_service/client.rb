# app/services/payment_service/client.rb
module PaymentService
  class Client
    class << self
      delegate :create_customer,
               :create_checkout_session,
               :get_session,
               :cancel_subscription,
               :resume_subscription,
               :create_product,
               :update_product,
               :discard_product,
               :undiscard_product,
               :create_coupon,
               :update_coupon,
               :discard_coupon,
               :undiscard_coupon,
               :destroy_coupon,
               :supported_webhook_event?,
               :verify_webhook,
               :process_webhook,
               to: :provider

      private

      def provider
        @provider ||= Stripe.new
      end
    end
  end
end
