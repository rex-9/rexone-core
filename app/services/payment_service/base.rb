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

    def resume_subscription(subscription_id)
      raise NotImplementedError, "#{self.class} must implement #resume_subscription"
    end

    def create_product(attributes)
      raise NotImplementedError, "#{self.class} must implement #create_product"
    end

    def update_product(product_id, attributes)
      raise NotImplementedError, "#{self.class} must implement #update_product"
    end

    def archive_product(product_id)
      raise NotImplementedError, "#{self.class} must implement #archive_product"
    end

    def restore_product(product_id)
      raise NotImplementedError, "#{self.class} must implement #restore_product"
    end

    def supported_webhook_event?(event_type)
      raise NotImplementedError, "#{self.class} must implement #supported_webhook_event?"
    end

    def verify_webhook(payload, signature)
      raise NotImplementedError, "#{self.class} must implement #verify_webhook"
    end

    def process_webhook(event)
      raise NotImplementedError, "#{self.class} must implement #process_webhook"
    end
  end
end
