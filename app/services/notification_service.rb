# app/services/notification_service.rb

class NotificationService
  LOG_PREFIX = "[NotificationService]".freeze
  CHANNELS = %w[socket push email].freeze
  AUDIENCES = %w[roles all].freeze

  class << self
    # ===== UNIFIED METHODS =====

    def notify(user_id:, user_email: nil, title: nil, message: nil, data: {}, send_socket: false, send_push: false, send_email: false, email_template: nil, email_template_data: {})
      results = {}

      # 1. Socket (WebSocket)
      if send_socket
        results[:socket] = enqueue(:socket) do
          {
            user_id: user_id,
            message: message || title,
            data: data
          }
        end
      end

      # 2. Push notification
      if send_push && title.present?
        results[:push] = enqueue(:push) do
          {
            user_id: user_id,
            title: title,
            body: message || title,
            data: data
          }
        end
      end

      # 3. Email
      if send_email
        results[:email] = enqueue(:email) do
          user_email ||= User.find(user_id).email

          if email_template.present?
            {
              to: user_email,
              template_id: email_template,
              template_data: email_template_data
            }
          else
            {
              to: user_email,
              subject: title || notification_message(MessageService::Notification::DEFAULT_TITLE),
              body: message || notification_message(MessageService::Notification::DEFAULT_BODY)
            }
          end
        end
      end

      results
    end

    # ===== PAYMENT NOTIFICATIONS =====

    def payment_success(user, product, transaction)
      notify(
        user_id: user.id,
        user_email: user.email,
        title: payment_message(MessageService::Payment::PAYMENT_SUCCESS_TITLE),
        message: payment_message(
          MessageService::Payment::PAYMENT_SUCCESS_BODY,
          product_name: product.name,
          amount: product.display_price
        ),
        data: { type: "payment_success", product_name: product.name, amount: product.display_price },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: EmailService::Templates::PURCHASE_CONFIRMATION,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          amount: product.display_price,
          date: transaction.paid_at.strftime("%B %d, %Y")
        }
      )
    end

    def subscription_created(user, product, subscription)
      notify(
        user_id: user.id,
        user_email: user.email,
        title: payment_message(
          MessageService::Payment::SUBSCRIPTION_CREATED_TITLE,
          product_name: product.name
        ),
        message: payment_message(MessageService::Payment::SUBSCRIPTION_CREATED_BODY),
        data: { type: "subscription_created", product_name: product.name },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: EmailService::Templates::SUBSCRIPTION_CONFIRMATION,
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

      notify(
        user_id: user.id,
        user_email: user.email,
        title: payment_message(MessageService::Payment::SUBSCRIPTION_CANCELED_TITLE),
        message: subscription_canceled_message(product, active_until),
        data: {
          type: "subscription_canceled",
          product_name: product.name,
          active_until: active_until&.iso8601
        },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: EmailService::Templates::SUBSCRIPTION_CANCELED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          canceled_on: subscription.canceled_at&.strftime("%B %d, %Y") ||
                      payment_message(MessageService::Payment::TODAY),
          valid_until: active_until&.strftime("%B %d, %Y") ||
                      payment_message(MessageService::Payment::END_OF_PERIOD)
        }
      )
    end

    def subscription_resumed(user, product, subscription)
      notify(
        user_id: user.id,
        user_email: user.email,
        title: payment_message(MessageService::Payment::SUBSCRIPTION_RESUMED_TITLE),
        message: payment_message(
          MessageService::Payment::SUBSCRIPTION_RESUMED_BODY,
          product_name: product.name
        ),
        data: { type: "subscription_resumed", product_name: product.name },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: EmailService::Templates::SUBSCRIPTION_RESUMED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          current_period_end: subscription.current_period_end.strftime("%B %d, %Y")
        }
      )
    end

    def payment_failed(user, product, subscription)
      notify(
        user_id: user.id,
        user_email: user.email,
        title: payment_message(MessageService::Payment::PAYMENT_FAILED_TITLE),
        message: payment_message(
          MessageService::Payment::PAYMENT_FAILED_BODY,
          product_name: product.name,
          amount: product.display_price
        ),
        data: { type: "payment_failed", product_name: product.name, amount: product.display_price },
        send_socket: true,
        send_push: true,
        send_email: true,
        email_template: EmailService::Templates::PAYMENT_FAILED,
        email_template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          due_date: subscription.current_period_end.strftime("%B %d, %Y")
        }
      )
    end

    # ===== AUTH NOTIFICATIONS =====

    def welcome(user_id:, name:)
      notify(
        user_id: user_id,
        title: notification_message(MessageService::Notification::WELCOME_TITLE),
        message: notification_message(
          MessageService::Notification::WELCOME_BODY,
          name: name
        ),
        data: { type: "welcome", name: name },
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    def sign_in_alert(user_id:, name:)
      notify(
        user_id: user_id,
        title: notification_message(MessageService::Notification::SIGN_IN_ALERT_TITLE),
        message: notification_message(
          MessageService::Notification::SIGN_IN_ALERT_BODY,
          name: name
        ),
        data: { type: "sign_in_alert", name: name },
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    # ===== EMAIL ONLY =====

    def confirmation_email(email:, code:)
      enqueue(:email) do
        {
          to: email,
          template_id: EmailService::Templates::CONFIRMATION,
          template_data: {
            code: code,
            email: email
          }
        }
      end
    end

    def password_reset_email(email:, token:)
      enqueue(:email) do
        {
          to: email,
          template_id: EmailService::Templates::PASSWORD_RESET,
          template_data: {
            token: token,
            email: email,
            reset_url: "#{AppConfig::CLIENT_BASE_URL}/passcode/reset?reset_password_token=#{token}"
          }
        }
      end
    end

    def email(email:, subject:, body:)
      enqueue(:email) do
        { to: email, subject: subject, body: body }
      end
    end

    private

    def notification_message(key, **options)
      MessageService::Notification.t(key, **options)
    end

    def payment_message(key, **options)
      MessageService::Payment.t(key, **options)
    end

    def subscription_canceled_message(product, active_until)
      key = if active_until.present?
        MessageService::Payment::SUBSCRIPTION_CANCELED_BODY_WITH_DATE
      else
        MessageService::Payment::SUBSCRIPTION_CANCELED_BODY
      end

      payment_message(
        key,
        product_name: product.name,
        active_until: active_until&.strftime("%B %d, %Y")
      )
    end

    def enqueue(channel)
      Notification::DeliverJob.perform_later(
        channel: channel,
        payload: yield
      )

      true
    rescue StandardError => error
      Rails.error.report(error)
      Rails.logger.error(
        "#{LOG_PREFIX} Could not enqueue #{channel} delivery: " \
        "#{error.class}: #{error.message}"
      )

      false
    end
  end
end
