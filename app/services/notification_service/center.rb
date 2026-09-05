# app/services/notification_service/center.rb

module NotificationService
  class Center
    LOG_PREFIX = "[NotificationService]".freeze
    CHANNELS = %w[socket push email].freeze
    AUDIENCES = %w[users roles all].freeze

    class << self
      # ===== UNIFIED METHODS =====

      def notify(user_id:, user_email: nil, title: nil, message: nil, push_title: nil, push_body: nil, link: nil, data: {}, send_socket: false, send_push: false, send_email: false, email_template: nil, email_template_data: {}, template_id: nil, push_template_id: nil, **kwargs)
        results = {}

        # 1. Socket (WebSocket + In-App Database Persistence)
        if send_socket
          user_notification = nil
          if User.exists?(id: user_id)
            user_notification = UserNotification.create(
              user_id: user_id,
              notification_id: template_id,
              title: title.presence || message.presence || "Notification",
              message: message.presence || title.presence || "Notification",
              link: link,
              data: data
            )
          end

          results[:socket] = enqueue(:socket) do
            if user_notification
              {
                user_id: user_id,
                id: user_notification.id,
                title: user_notification.title,
                message: user_notification.message,
                link: user_notification.link,
                data: user_notification.data,
                read_at: user_notification.read_at,
                created_at: user_notification.created_at.iso8601
              }
            else
              {
                user_id: user_id,
                message: message || title,
                data: data
              }
            end
          end
        end

        # 2. Push notification
        if send_push && (push_title.present? || title.present? || push_template_id.present?)
          results[:push] = enqueue(:push) do
            {
              user_id: user_id,
              title: push_title.presence || title,
              body: push_body.presence || message || title,
              data: data.merge(link: link).compact,
              template_id: push_template_id
            }.compact
          end
        end

        # 3. Email
        if send_email
          results[:email] = enqueue(:email) do
            user_email ||= User.find_by(id: user_id)&.email

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

      def payment_success(user, product, transaction, **kwargs)
        template = template_for(NotificationConstants::NotificationType::PAYMENT_SUCCESS)
        context = {
          product_name: product.name,
          amount: product.display_price,
          date: transaction.paid_at.strftime("%B %d, %Y")
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_SUCCESS_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_SUCCESS_BODY, product_name: product.name, amount: product.display_price)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/payment/transactions"

        notify(
          user_id: user.id,
          user_email: user.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::PAYMENT_SUCCESS, product_name: product.name, amount: product.display_price },
          send_socket: true,
          send_push: true,
          send_email: true,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "payment_purchase_confirmation",
          email_template_data: {
            user_name: user.name || user.username,
            product_name: product.name,
            amount: product.display_price,
            date: transaction.paid_at.strftime("%B %d, %Y")
          },
          **kwargs
        )
      end

      def subscription_created(user, product, subscription, **kwargs)
        template = template_for(NotificationConstants::NotificationType::SUBSCRIPTION_CREATED)
        context = {
          product_name: product.name,
          period: product.period_label,
          active_until: format_date(Time.zone.at(subscription.current_period_end))
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_CREATED_TITLE, product_name: product.name)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_CREATED_BODY)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/payment/subscriptions"

        notify(
          user_id: user.id,
          user_email: user.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::SUBSCRIPTION_CREATED, product_name: product.name, active_until: subscription.current_period_end },
          send_socket: true,
          send_push: true,
          send_email: true,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "payment_subscription_confirmation",
          email_template_data: {
            user_name: user.name || user.username,
            product_name: product.name,
            current_period_start: format_date(Time.zone.at(subscription.current_period_start)),
            current_period_end: format_date(Time.zone.at(subscription.current_period_end)),
            period: product.period_label
          },
          **kwargs
        )
      end

      def subscription_canceled(user, product, subscription, **kwargs)
        active_until = subscription.current_period_end
        template = template_for(NotificationConstants::NotificationType::SUBSCRIPTION_CANCELED)
        context = {
          product_name: product.name,
          active_until: active_until ? Time.zone.at(active_until).strftime("%B %d, %Y") : nil
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_CANCELED_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : subscription_canceled_message(product, active_until)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/payment/subscriptions"

        notify(
          user_id: user.id,
          user_email: user.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: {
            type: NotificationConstants::NotificationType::SUBSCRIPTION_CANCELED,
            product_name: product.name,
            active_until: active_until ? Time.zone.at(active_until).iso8601 : nil
          },
          send_socket: true,
          send_push: true,
          send_email: true,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "payment_subscription_canceled",
          email_template_data: {
            user_name: user.name || user.username,
            product_name: product.name,
            canceled_on: subscription.canceled_at ? Time.zone.at(subscription.canceled_at).strftime("%B %d, %Y") : payment_message(MessageService::Payment::TODAY),
            valid_until: active_until ? Time.zone.at(active_until).strftime("%B %d, %Y") : payment_message(MessageService::Payment::END_OF_PERIOD)
          },
          **kwargs
        )
      end

      def subscription_resumed(user, product, subscription, **kwargs)
        template = template_for(NotificationConstants::NotificationType::SUBSCRIPTION_RESUMED)
        context = { product_name: product.name }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_RESUMED_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_RESUMED_BODY, product_name: product.name)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/payment/subscriptions"

        notify(
          user_id: user.id,
          user_email: user.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::SUBSCRIPTION_RESUMED, product_name: product.name },
          send_socket: true,
          send_push: true,
          send_email: true,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "payment_subscription_resumed",
          email_template_data: {
            user_name: user.name || user.username,
            product_name: product.name,
            current_period_end: Time.zone.at(subscription.current_period_end).strftime("%B %d, %Y")
          },
          **kwargs
        )
      end

      def payment_failed(user, product, subscription, **kwargs)
        template = template_for(NotificationConstants::NotificationType::PAYMENT_FAILED)
        context = {
          product_name: product.name,
          amount: product.display_price,
          due_date: Time.zone.at(subscription.current_period_end).strftime("%B %d, %Y")
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_FAILED_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_FAILED_BODY, product_name: product.name, amount: product.display_price)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/payment/subscriptions"

        notify(
          user_id: user.id,
          user_email: user.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::PAYMENT_FAILED, product_name: product.name, amount: product.display_price },
          send_socket: true,
          send_push: true,
          send_email: true,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "payment_failed",
          email_template_data: {
            user_name: user.name || user.username,
            product_name: product.name,
            due_date: Time.zone.at(subscription.current_period_end).strftime("%B %d, %Y")
          },
          **kwargs
        )
      end

      # ===== AUTH NOTIFICATIONS =====

      def welcome(user_id:, name:, **kwargs)
        user = User.find_by(id: user_id)
        template = template_for(NotificationConstants::NotificationType::WELCOME)
        context = { name: name }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : notification_message(MessageService::Notification::WELCOME_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : notification_message(MessageService::Notification::WELCOME_BODY, name: name)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/"

        notify(
          user_id: user_id,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::WELCOME, name: name },
          send_push: true,
          send_socket: true,
          send_email: false,
          push_template_id: template&.push_template_id,
          **kwargs
        )
      end

      def sign_in_alert(user_id:, name:, **kwargs)
        user = User.find_by(id: user_id)
        template = template_for(NotificationConstants::NotificationType::SIGN_IN_ALERT)
        context = { name: name, time: Time.current.strftime("%B %d, %Y %H:%M UTC") }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : notification_message(MessageService::Notification::SIGN_IN_ALERT_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : notification_message(MessageService::Notification::SIGN_IN_ALERT_BODY, name: name)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template&.link.presence || "/settings"

        notify(
          user_id: user_id,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::SIGN_IN_ALERT, time: Time.current.iso8601 },
          send_push: true,
          send_socket: true,
          send_email: false,
          push_template_id: template&.push_template_id,
          **kwargs
        )
      end

      # ===== EMAIL ONLY =====

      def confirmation_email(email:, code:, **kwargs)
        enqueue(:email) do
          {
            to: email,
            template_id: "email_confirmation",
            template_data: {
              code: code,
              email: email
            }
          }
        end
      end

      def password_reset_email(email:, token:, **kwargs)
        enqueue(:email) do
          {
            to: email,
            template_id: "password_reset",
            template_data: {
              token: token,
              email: email,
              reset_url: "#{AppConfig::CLIENT_BASE_URL}#{AuthConstants::ClientRoutes::PASSWORD_RESET}?reset_password_token=#{token}"
            }
          }
        end
      end

      def email(email:, subject:, body:, **kwargs)
        enqueue(:email) do
          { to: email, subject: subject, body: body }
        end
      end

      private

      def template_for(event)
        return nil unless defined?(Notification)

        Notification.find_by(event: event)
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def format_date(time)
        time&.strftime("%B %d, %Y")
      end

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
          active_until: active_until ? (active_until.is_a?(Numeric) ? Time.zone.at(active_until).strftime("%B %d, %Y") : active_until.strftime("%B %d, %Y")) : nil
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
end
