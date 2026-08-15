# app/services/notification_service.rb

class NotificationService
  class << self
    # ===== UNIFIED METHODS =====

    def notify_all(user_id:, user_email: nil, title: nil, message: nil, data: {}, send_socket: false, send_push: false, send_email: false, email_template: nil, email_template_data: {})
      results = {}

      # 1. Socket (WebSocket)
      if send_socket
        results[:socket] = deliver(:socket) do
          SocketService::Client.broadcast(
            user_id: user_id,
            message: message || title,
            data: data
          )
        end
      end

      # 2. Push notification
      if send_push && title.present?
        results[:push] = deliver(:push) do
          PushNotiService::Client.send_to_user(
            user_id: user_id,
            title: title,
            body: message || title,
            data: data
          )
        end
      end

      # 3. Email
      if send_email
        results[:email] = deliver(:email) do
          user_email ||= User.find(user_id).email

          if email_template.present?
            EmailService::Client.send_template(
              to: user_email,
              template_id: email_template,
              template_data: email_template_data
            )
          else
            EmailService::Client.send_email(
              to: user_email,
              subject: title || "Notification",
              body: message || "You have a new notification."
            )
          end
        end
      end

      results
    end

    # ===== PAYMENT NOTIFICATIONS =====

    def payment_success(user, product, transaction)
      notify_all(
        user_id: user.id,
        user_email: user.email,
        title: Messages::PAYMENT_SUCCESS_TITLE,
        message: Messages::PAYMENT_SUCCESS_BODY.call(product_name: product.name, amount: product.display_price),
        data: { type: "payment_success", product_name: product.name, amount: product.display_price },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: Messages::EMAIL_TEMPLATE_PURCHASE_CONFIRMATION,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          amount: product.display_price,
          date: transaction.paid_at.strftime("%B %d, %Y")
        }
      )
    end

    def subscription_created(user, product, subscription)
      notify_all(
        user_id: user.id,
        user_email: user.email,
        title: Messages::SUBSCRIPTION_CREATED_TITLE.call(product_name: product.name),
        message: Messages::SUBSCRIPTION_CREATED_BODY,
        data: { type: "subscription_created", product_name: product.name },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: Messages::EMAIL_TEMPLATE_SUBSCRIPTION_CONFIRMATION,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          current_period_start: subscription.current_period_start.strftime("%B %d, %Y"),
          current_period_end: subscription.current_period_end.strftime("%B %d, %Y"),
          period: product.period_label
        }
      )
    end

    def subscription_canceled(user, product, subscription)
      active_until = subscription.current_period_end

      notify_all(
        user_id: user.id,
        user_email: user.email,
        title: Messages::SUBSCRIPTION_CANCELED_TITLE,
        message: Messages::SUBSCRIPTION_CANCELED_BODY.call(
          product_name: product.name,
          active_until: active_until&.strftime("%B %d, %Y")
        ),
        data: {
          type: "subscription_canceled",
          product_name: product.name,
          active_until: active_until&.iso8601
        },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: Messages::EMAIL_TEMPLATE_SUBSCRIPTION_CANCELED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          canceled_on: subscription.canceled_at&.strftime("%B %d, %Y") ||
                      "Today",
          valid_until: active_until&.strftime("%B %d, %Y") ||
                      "End of period"
        }
      )
    end

    def subscription_resumed(user, product, subscription)
      notify_all(
        user_id: user.id,
        user_email: user.email,
        title: Messages::SUBSCRIPTION_RESUMED_TITLE,
        message: Messages::SUBSCRIPTION_RESUMED_BODY.call(product_name: product.name),
        data: { type: "subscription_resumed", product_name: product.name },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: Messages::EMAIL_TEMPLATE_SUBSCRIPTION_RESUMED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          current_period_end: subscription.current_period_end.strftime("%B %d, %Y")
        }
      )
    end

    def payment_failed(user, product, subscription)
      notify_all(
        user_id: user.id,
        user_email: user.email,
        title: Messages::PAYMENT_FAILED_TITLE,
        message: Messages::PAYMENT_FAILED_BODY.call(product_name: product.name, amount: product.display_price),
        data: { type: "payment_failed", product_name: product.name, amount: product.display_price },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: Messages::EMAIL_TEMPLATE_PAYMENT_FAILED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          due_date: subscription.current_period_end.strftime("%B %d, %Y")
        }
      )
    end

    # ===== AUTH NOTIFICATIONS =====

    def welcome(user_id:, name:)
      notify_all(
        user_id: user_id,
        title: Messages::PUSH_WELCOME_TITLE,
        message: Messages::PUSH_WELCOME_BODY.call(name: name),
        data: { type: "welcome", name: name },
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    def sign_in_alert(user_id:, name:)
      notify_all(
        user_id: user_id,
        title: Messages::PUSH_SIGN_IN_ALERT_TITLE,
        message: Messages::PUSH_SIGN_IN_ALERT_BODY.call(name: name),
        data: { type: "sign_in_alert", name: name },
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    # ===== EMAIL ONLY =====

    def confirmation_email(email:, code:)
      EmailService::Client.send_template(
        to: email,
        template_id: Messages::EMAIL_TEMPLATE_CONFIRMATION,
        template_data: {
          code: code,
          email: email
        }
      )
    end

    def password_reset_email(email:, token:)
      EmailService::Client.send_template(
        to: email,
        template_id: Messages::EMAIL_TEMPLATE_PASSWORD_RESET,
        template_data: {
          token: token,
          email: email,
          reset_url: "#{AppConfig::CLIENT_BASE_URL}/passcode/reset?reset_password_token=#{token}"
        }
      )
    end

    # ===== CUSTOM =====

    def custom(user_id:, title:, message:, data: {}, send_push: true, send_socket: false, send_email: false, email_template: nil, email_template_data: {})
      notify_all(
        user_id: user_id,
        title: title,
        message: message,
        data: data,
        send_push: send_push,
        send_socket: send_socket,
        send_email: send_email,
        email_template: email_template,
        email_template_data: email_template_data
      )
    end

    private

    def deliver(channel)
      yield
    rescue StandardError => error
      Rails.error.report(error)
      Rails.logger.error(
        "[NotificationService] #{channel} delivery failed: " \
        "#{error.class}: #{error.message}"
      )

      { error: error.message }
    end
  end
end
