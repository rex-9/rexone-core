# app/services/notification_service/center.rb

module NotificationService
  class Center
    LOG_PREFIX = "[NotificationService]".freeze
    CHANNELS = %w[socket push email].freeze
    AUDIENCES = %w[users roles all].freeze

    class << self
      # ===== UNIFIED METHODS =====

      def operation(user_id:, operation_id:, operation_type:, operation_status:, message:, link:, data: {}, clients: nil)
        notify(
          user_id: user_id,
          title: message,
          message: message,
          operation_id: operation_id,
          operation_type: operation_type,
          operation_status: operation_status,
          link: link,
          clients: clients,
          data: data,
          send_socket: true
        )
      end

      def notify(user_id:, user_email: nil, title: nil, message: nil, push_title: nil, push_body: nil, link: nil, clients: nil, data: {}, operation_id: nil, operation_type: nil, operation_status: nil, send_socket: false, send_push: false, send_email: false, email_template: nil, email_template_data: {}, template_id: nil, push_template_id: nil, **kwargs)
        results = {}
        data = data.dup
        clients ||= Notification.find_by(id: template_id)&.clients if template_id.present?
        clients = notification_clients(clients, link)
        push_requested = send_push && clients.include?(NotificationConstants::Client::MOBILE) && (push_title.present? || title.present? || push_template_id.present?)
        # Every push has one canonical persisted in-app notification. This gives
        # every client the same UserNotification ID for open analytics.
        send_socket ||= push_requested
        operation_data = {
          operation_id: operation_id,
          operation_type: operation_type,
          operation_status: operation_status,
          link: link
        }.compact
        data = data.merge(operation_data)

        # 1. Socket (WebSocket + In-App Database Persistence)
        if send_socket
          user_notification = nil
          if User.exists?(id: user_id)
            user_notification = if operation_id.present?
              NotificationService::OperationTracker.transition(
                operation: {
                  user_id: user_id,
                  operation_id: operation_id,
                  operation_type: operation_type,
                  title: title.presence || message.presence || "Notification",
                  message: message.presence || title.presence || "Notification",
                  link: link,
                  clients: clients,
                  data: data
                },
                status: operation_status,
                broadcast: false
              )
            else
              UserNotification.new(user_id: user_id)
            end
            if user_notification && operation_id.blank?
              user_notification.assign_attributes(
                user_id: user_id,
                notification_id: template_id,
                title: title.presence || message.presence || "Notification",
                message: message.presence || title.presence || "Notification",
                link: link,
                clients: clients,
                metadata: data,
                read_at: nil
              )
              user_notification.save!
            end
          end

          results[:socket] = enqueue(:socket) do
            if user_notification
              {
                user_id: user_id,
                id: user_notification.id,
                title: user_notification.title,
                message: user_notification.message,
                link: user_notification.link,
                clients: user_notification.clients,
                data: user_notification.metadata,
                read_at: user_notification.read_at,
                created_at: user_notification.created_at.iso8601
              }.compact
            else
              {
                user_id: user_id,
                message: message || title,
                clients: clients,
                data: data
              }
            end
          end
        end

        # 2. Push notification
        if push_requested
          push_data = data.merge(
            AnalyticsConstants::Parameter::NOTIFICATION_ID => user_notification&.id
          ).compact
          results[:push] = enqueue(
            :push,
            operation: delivery_operation(
              channel: NotificationConstants::Channel::PUSH,
              user_id: user_id,
              operation_id: operation_id,
              title: push_title.presence || title,
              message: push_body.presence || message || title,
              link: link,
              data: push_data
            )
          ) do
            {
              user_id: user_id,
              title: push_title.presence || title,
              body: push_body.presence || message || title,
              data: push_data.merge(link: link).compact,
              template_id: push_template_id
            }.compact
          end
        end

        # 3. Email
        if send_email
          results[:email] = enqueue(
            :email,
            operation: delivery_operation(
              channel: NotificationConstants::Channel::EMAIL,
              user_id: user_id,
              operation_id: operation_id,
              title: title || notification_message(MessageService::Notification::DEFAULT_TITLE),
              message: message || notification_message(MessageService::Notification::DEFAULT_BODY),
              link: link,
              data: data
            )
          ) do
            user_email ||= User.find_by(id: user_id)&.email
            email_link = AppConfig.client_url(link) if link.present?

            if email_template.present?
              {
                to: user_email,
                template_id: email_template,
                template_data: email_template_data.merge({ link: email_link, cta_url: email_link }.compact)
              }
            else
              resolved_subject = email_template_data[:subject].presence ||
                                 email_template_data[:title].presence ||
                                 title ||
                                 notification_message(MessageService::Notification::DEFAULT_TITLE)
              resolved_body = email_template_data[:body].presence ||
                              email_template_data[:message].presence ||
                              message ||
                              notification_message(MessageService::Notification::DEFAULT_BODY)
              {
                to: user_email,
                subject: resolved_subject,
                body: resolved_body,
                data: data.merge(email_template_data).merge({ link: email_link, cta_url: email_link }.compact)
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
        link = template_link(template, NotificationConstants::Link::PAYMENT)

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
          active_until: format_date(subscription.current_period_end)
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_CREATED_TITLE, product_name: product.name)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::SUBSCRIPTION_CREATED_BODY)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template_link(template, NotificationConstants::Link::PAYMENT)

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
            current_period_start: format_date(subscription.current_period_start),
            current_period_end: format_date(subscription.current_period_end),
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
        link = template_link(template, NotificationConstants::Link::PAYMENT)

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
            canceled_on: subscription.canceled_at ? format_date(subscription.canceled_at) : payment_message(MessageService::Payment::TODAY),
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
        link = template_link(template, NotificationConstants::Link::PAYMENT)

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
            current_period_end: format_date(subscription.current_period_end)
          },
          **kwargs
        )
      end

      def payment_failed(user, product, subscription, **kwargs)
        template = template_for(NotificationConstants::NotificationType::PAYMENT_FAILED)
        context = {
          product_name: product.name,
          amount: product.display_price,
          due_date: format_date(subscription.current_period_end)
        }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_FAILED_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : payment_message(MessageService::Payment::PAYMENT_FAILED_BODY, product_name: product.name, amount: product.display_price)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template_link(template, NotificationConstants::Link::PAYMENT)

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
            due_date: format_date(subscription.current_period_end)
          },
          **kwargs
        )
      end

      # ===== AUTH NOTIFICATIONS =====

      def welcome(user, **kwargs)
        user = user.is_a?(User) ? user : User.find_by(id: user)
        user_name = user&.name.presence || user&.username.presence || "User"
        template = template_for(NotificationConstants::NotificationType::WELCOME)
        context = { user_name: user_name }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : notification_message(MessageService::Notification::WELCOME_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : notification_message(MessageService::Notification::WELCOME_BODY, name: user_name)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template_link(template, NotificationConstants::Link::HOME)

        notify(
          user_id: user&.id,
          user_email: user&.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::WELCOME, user_name: user_name },
          send_push: true,
          send_socket: true,
          send_email: false,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "welcome",
          email_template_data: {
            user_name: user_name
          },
          **kwargs
        )
      end

      def sign_in_alert(user, **kwargs)
        user = user.is_a?(User) ? user : User.find_by(id: user)
        user_name = user&.name.presence || user&.username.presence || "User"
        time_str = Time.current.strftime("%B %d, %Y %H:%M UTC")
        template = template_for(NotificationConstants::NotificationType::SIGN_IN_ALERT)
        context = { user_name: user_name, time: time_str }

        title = template ? template.render_text(template.in_app_title, user: user, context: context) : notification_message(MessageService::Notification::SIGN_IN_ALERT_TITLE)
        message = template ? template.render_text(template.in_app_body, user: user, context: context) : notification_message(MessageService::Notification::SIGN_IN_ALERT_BODY, name: user_name)
        push_title = template ? template.render_text(template.push_title.presence || template.in_app_title, user: user, context: context) : title
        push_body = template ? template.render_text(template.push_body.presence || template.in_app_body, user: user, context: context) : message
        link = template_link(template, NotificationConstants::Link::PROFILE)

        notify(
          user_id: user&.id,
          user_email: user&.email,
          template_id: template&.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: link,
          data: { type: NotificationConstants::NotificationType::SIGN_IN_ALERT, time: Time.current.iso8601, user_name: user_name },
          send_push: true,
          send_socket: true,
          send_email: false,
          push_template_id: template&.push_template_id,
          email_template: template&.email_template_id.presence || "sign_in_alert",
          email_template_data: {
            user_name: user_name,
            time: time_str
          },
          **kwargs
        )
      end

      def iam_updated(user)
        notify(
          user_id: user.id,
          title: notification_message(MessageService::Notification::IAM_UPDATED_TITLE),
          message: notification_message(MessageService::Notification::IAM_UPDATED_BODY),
          data: { type: NotificationConstants::NotificationType::IAM_UPDATED },
          send_socket: true
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

      def notification_clients(clients, link)
        return NotificationConstants::Client::ADMIN_PORTAL if link.to_s.start_with?("/admin")

        values = Array(clients.presence || NotificationConstants::Client::DEFAULT).map(&:to_s).uniq
        values.presence || NotificationConstants::Client::DEFAULT
      end

      def template_for(event)
        return nil unless defined?(Notification)

        Notification.find_by(event: event)
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def template_link(template, fallback)
        return fallback unless template&.link.present?
        return template.link if template.link.in?(NotificationConstants::Link::TEMPLATE_LINKS)
        return template.link if template.link.start_with?(NotificationConstants::Link::HTTPS_PREFIX)

        fallback
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

      def delivery_operation(channel:, user_id:, operation_id:, title:, message:, link:, data:)
        return if operation_id.blank? || User.exists?(id: user_id) == false

        {
          user_id: user_id,
          operation_id: "#{operation_id}:#{channel}",
          operation_type: NotificationConstants::OperationType::NOTIFICATION_DELIVERY,
          title: title,
          message: message,
          link: link.presence || NotificationConstants::Link::HOME,
          data: data.merge(channel: channel)
        }
      end

      def enqueue(channel, operation: nil)
        NotificationService::OperationTracker.transition(
          operation: operation,
          status: NotificationConstants::OperationStatus::QUEUED
        ) if operation

        arguments = {
          channel: channel,
          payload: yield
        }
        arguments[:operation] = operation if operation
        Notification::DeliverJob.perform_later(**arguments)

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
