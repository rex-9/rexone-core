module NotificationService
  class OperationTracker
    LOG_PREFIX = "[NotificationOperation]".freeze

    class << self
      def transition(operation:, status:, error: nil, broadcast: true)
        attributes = operation.symbolize_keys
        notification = UserNotification.find_or_initialize_by(
          user_id: attributes.fetch(:user_id),
          operation_id: attributes.fetch(:operation_id)
        )
        clients = if attributes[:link].to_s.start_with?("/admin")
          NotificationConstants::Client::ADMIN_PORTAL
        else
          attributes[:clients] || notification.clients.presence || NotificationConstants::Client::DEFAULT
        end
        metadata = (attributes[:data] || {}).merge(
          operation_id: attributes.fetch(:operation_id),
          operation_type: attributes.fetch(:operation_type),
          operation_status: status,
          link: attributes[:link]
        ).compact
        notification.assign_attributes(
          title: attributes.fetch(:title),
          message: error.presence || attributes.fetch(:message),
          link: attributes[:link],
          clients: clients,
          operation_type: attributes.fetch(:operation_type),
          operation_status: status,
          metadata: metadata,
          read_at: nil
        )
        notification.save!

        if broadcast
          SocketService::Client.broadcast(
            user_id: notification.user_id,
            id: notification.id,
            title: notification.title,
            message: notification.message,
            link: notification.link,
            clients: notification.clients,
            data: notification.metadata,
            read_at: notification.read_at,
            created_at: notification.created_at.iso8601
          )
        end

        notification
      rescue StandardError => exception
        Rails.error.report(exception)
        Rails.logger.error("#{LOG_PREFIX} transition failed: #{exception.class}: #{exception.message}")
        nil
      end
    end
  end
end
