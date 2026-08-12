# app/services/socket_service/action_cable.rb
module SocketService
  class ActionCable < Base
    ActionCable = ::ActionCable

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
    # (via streamed from user_0917b97f-b7cb-4d03-a6fb-f36ba1421731_notifications)

    def broadcast(user_id:, message:, data: {})
      ActionCable.server.broadcast(
        "user_#{user_id}_notifications",
        {
          type: "notification",
          message: message,
          data: data,
          created_at: Time.current.iso8601
        }
      )
      true
    rescue => e
      Rails.logger.error("[Socket] Broadcast error for user #{user_id}: #{e.message}")
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
      Rails.logger.error("[Socket] Channel broadcast error to #{channel}: #{e.message}")
      nil
    end
  end
end
