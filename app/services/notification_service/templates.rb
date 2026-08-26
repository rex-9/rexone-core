# app/services/notification_service/templates.rb
module NotificationService
  module Templates
    CONFIRMATION = "email_confirmation"
    PASSWORD_RESET = "password_reset"
    PURCHASE_CONFIRMATION = "payment_purchase_confirmation"
    SUBSCRIPTION_CONFIRMATION = "payment_subscription_confirmation"
    SUBSCRIPTION_CANCELED = "payment_subscription_canceled"
    SUBSCRIPTION_RESUMED = "payment_subscription_resumed"
    PAYMENT_FAILED = "payment_failed"
    GENERAL_ANNOUNCEMENT = "general_announcement"
    MAINTENANCE_NOTICE = "maintenance_notice"
    FEATURE_UPDATE = "feature_update"

    ALL = constants(false).to_h { |name| [ name, const_get(name) ] }.freeze

    CATALOG = {
      GENERAL_ANNOUNCEMENT => {
        label: "General announcement", category: "broadcast", admin_available: true,
        email_template: GENERAL_ANNOUNCEMENT
      },
      MAINTENANCE_NOTICE => {
        label: "Maintenance notice", category: "broadcast", admin_available: true,
        email_template: MAINTENANCE_NOTICE
      },
      FEATURE_UPDATE => {
        label: "Feature update", category: "broadcast", admin_available: true,
        email_template: FEATURE_UPDATE
      },
      CONFIRMATION => {
        label: "Email confirmation", category: "authentication", admin_available: false,
        unavailable_reason: "Requires a confirmation code"
      },
      PASSWORD_RESET => {
        label: "Password reset", category: "authentication", admin_available: false,
        unavailable_reason: "Requires a password reset token"
      },
      PURCHASE_CONFIRMATION => {
        label: "Purchase confirmation", category: "payment", admin_available: false,
        unavailable_reason: "Requires purchase and product data"
      },
      SUBSCRIPTION_CONFIRMATION => {
        label: "Subscription confirmation", category: "payment", admin_available: false,
        unavailable_reason: "Requires subscription and product data"
      },
      SUBSCRIPTION_CANCELED => {
        label: "Subscription canceled", category: "payment", admin_available: false,
        unavailable_reason: "Requires subscription and product data"
      },
      SUBSCRIPTION_RESUMED => {
        label: "Subscription resumed", category: "payment", admin_available: false,
        unavailable_reason: "Requires subscription and product data"
      },
      PAYMENT_FAILED => {
        label: "Payment failed", category: "payment", admin_available: false,
        unavailable_reason: "Requires payment and product data"
      }
    }.freeze

    class << self
      def catalog
        CATALOG.map do |event, metadata|
          metadata.except(:email_template).merge(event: event)
        end
      end

      def admin_available?(event)
        CATALOG.dig(event, :admin_available) == true
      end

      def render(event)
        raise ArgumentError, "Unknown notification event: #{event}" unless admin_available?(event)

        title = I18n.t("notification.templates.#{event}.title")
        message = I18n.t("notification.templates.#{event}.body")

        {
          title: title,
          message: message,
          data: { type: event },
          email_template: CATALOG.dig(event, :email_template),
          email_template_data: { event: event, title: title, message: message }
        }
      end
    end
  end
end
