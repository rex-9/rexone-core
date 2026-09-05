# app/constants/notification_constants/default_notifications.rb

module NotificationConstants
  module DefaultNotifications
    ALL = [
      {
        event: NotificationType::WELCOME,
        name: "Welcome to Rexone",
        description: "Sent when a new user joins the platform",
        category: Category::SYSTEM,
        link: "/",
        admin: true,
        in_app_title: "Welcome aboard! 🎉",
        in_app_body: "Hey {{user_name}}, thanks for joining Rexone! We're excited to have you.",
        push_title: "Welcome aboard! 🎉",
        push_body: "Hey {{user_name}}, thanks for joining Rexone!",
        email_subject: "Welcome to Rexone!",
        email_body: "Welcome to Rexone, {{user_name}}!"
      }.freeze,
      {
        event: NotificationType::SIGN_IN_ALERT,
        name: "New Sign In Alert",
        description: "Sent when a new sign-in is detected",
        category: Category::SYSTEM,
        link: "/settings",
        admin: true,
        in_app_title: "New Sign In",
        in_app_body: "Hi {{user_name}}, we noticed a new sign-in to your account at {{time}}.",
        push_title: "New Sign In",
        push_body: "Hi {{user_name}}, new sign-in detected.",
        email_subject: "Security Alert: New Sign In",
        email_body: "Hi {{user_name}}, we noticed a new sign-in to your account."
      }.freeze,
      {
        event: NotificationType::PAYMENT_SUCCESS,
        name: "Payment Success",
        description: "Sent upon successful payment processing",
        category: Category::SYSTEM,
        link: "/payment/transactions",
        admin: true,
        in_app_title: "Payment Successful",
        in_app_body: "Your payment of {{amount}} for {{product_name}} was completed successfully.",
        push_title: "Payment Successful",
        push_body: "Payment of {{amount}} received for {{product_name}}.",
        email_subject: "Payment Confirmation - {{product_name}}",
        email_template_id: "payment_purchase_confirmation"
      }.freeze,
      {
        event: NotificationType::PAYMENT_FAILED,
        name: "Payment Failed",
        description: "Sent when an invoice payment fails",
        category: Category::SYSTEM,
        link: "/payment/subscriptions",
        admin: true,
        in_app_title: "Payment Failed",
        in_app_body: "Your payment of {{amount}} for {{product_name}} could not be processed.",
        push_title: "Payment Failed",
        push_body: "Payment failed for {{product_name}}.",
        email_subject: "Payment Failed - Action Required",
        email_template_id: "payment_failed"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_CREATED,
        name: "Subscription Started",
        description: "Sent when a new subscription is activated",
        category: Category::SYSTEM,
        link: "/payment/subscriptions",
        admin: true,
        in_app_title: "Subscription Started",
        in_app_body: "You are now subscribed to {{product_name}} ({{period}}).",
        push_title: "Subscription Started",
        push_body: "You are subscribed to {{product_name}}.",
        email_subject: "Subscription Confirmation - {{product_name}}",
        email_template_id: "payment_subscription_confirmation"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_CANCELED,
        name: "Subscription Canceled",
        description: "Sent when a subscription cancellation is scheduled",
        category: Category::SYSTEM,
        link: "/payment/subscriptions",
        admin: true,
        in_app_title: "Subscription Canceled",
        in_app_body: "Your subscription to {{product_name}} has been canceled. Access remains active until {{active_until}}.",
        push_title: "Subscription Canceled",
        push_body: "Subscription to {{product_name}} canceled.",
        email_subject: "Subscription Canceled",
        email_template_id: "payment_subscription_canceled"
      }.freeze,
      {
        event: NotificationType::SUBSCRIPTION_RESUMED,
        name: "Subscription Resumed",
        description: "Sent when a pending canceled subscription is resumed",
        category: Category::SYSTEM,
        link: "/payment/subscriptions",
        admin: true,
        in_app_title: "Subscription Resumed",
        in_app_body: "Your subscription to {{product_name}} has been successfully resumed.",
        push_title: "Subscription Resumed",
        push_body: "Subscription to {{product_name}} resumed.",
        email_subject: "Subscription Resumed",
        email_template_id: "payment_subscription_resumed"
      }.freeze
    ].freeze
  end
end
