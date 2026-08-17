module EmailService
  module Templates
    CONFIRMATION = "email_confirmation"
    PASSWORD_RESET = "password_reset"
    PURCHASE_CONFIRMATION = "payment_purchase_confirmation"
    SUBSCRIPTION_CONFIRMATION = "payment_subscription_confirmation"
    SUBSCRIPTION_CANCELED = "payment_subscription_canceled"
    SUBSCRIPTION_RESUMED = "payment_subscription_resumed"
    PAYMENT_FAILED = "payment_failed"

    ALL = constants(false).to_h { |name| [ name, const_get(name) ] }.freeze
  end
end
