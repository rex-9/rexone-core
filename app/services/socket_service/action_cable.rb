# app/services/socket_service/action_cable.rb
module SocketService
  class ActionCable < Base
    ActionCable = ::ActionCable
    LOG_PREFIX = "[Socket]".freeze

    # NotificationChannel transmitting {
    #   "type" => "notification",
    #   "message" => "Your subscription to Monthly Subscription has been canceled.",
    #   "data" => {
    #     "type" => "subscription_canceled",
    #     "product_name" => "Monthly Subscription",
    #     "active_until" => nil
    #   },
    #   "created_at" => "2026-08-01T02:15:17Z"
    # }
    # (via streamed from notification_user_0917b97f-b7cb-4d03-a6fb-f36ba1421731)

    def broadcast(user_id:, message:, data: {}, id: nil, title: nil, link: nil, read_at: nil, created_at: nil)
      payload = {
        id: id,
        type: NotificationConstants::NotificationType::NOTIFICATION,
        title: title,
        message: message,
        link: link,
        data: data,
        read_at: read_at,
        created_at: created_at || Time.current.iso8601
      }.compact

      ActionCable.server.broadcast(
        "notification_user_#{user_id}",
        payload
      )
      true
    rescue => e
      Rails.logger.error(
        "#{LOG_PREFIX} Broadcast error for user #{user_id}: #{e.message}"
      )
      nil
    end

    def broadcast_to_channel(channel:, message:, data: {})
      ActionCable.server.broadcast(
        channel,
        {
          type: "message",
          message: message,
          data: data
        }
      )
    rescue => e
      Rails.logger.error(
        "#{LOG_PREFIX} Channel broadcast error to #{channel}: #{e.message}"
      )
      nil
    end
  end
end
