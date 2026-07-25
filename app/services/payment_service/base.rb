# app/services/payment_service/base.rb
module PaymentService
  class Base
    def create_checkout_session(user_id:, product_id:, success_url: nil, cancel_url: nil)
      raise NotImplementedError, "#{self.class} must implement #create_checkout_session"
    end

    def get_session(session_id)
      raise NotImplementedError, "#{self.class} must implement #get_session"
    end

    def cancel_subscription(subscription_id)
      raise NotImplementedError, "#{self.class} must implement #cancel_subscription"
    end

    def get_subscription(subscription_id)
      raise NotImplementedError, "#{self.class} must implement #get_subscription"
    end

    def handle_webhook(payload, signature)
      raise NotImplementedError, "#{self.class} must implement #handle_webhook"
    end
  end
end
