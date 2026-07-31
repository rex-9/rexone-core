# app/channels/notification_channel.rb

class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user_#{current_user.id}_notifications"
  end

  def unsubscribed
    # Cleanup if needed
  end

  def receive(data)
    # Handle client messages if needed
    case data["action"]
    when "mark_read"
      mark_notification_read(data["notification_id"])
    else
      transmit({
        status: "error",
        error: "Unknown action"
      })
    end
  end

  private

  def mark_notification_read(notification_id)
    notification = current_user.notifications.find_by(id: notification_id)
    if notification
      notification.update(read_at: Time.current)
      transmit({
        status: "success",
        message: "Notification marked as read",
        notification_id: notification_id
      })
    else
      transmit({
        status: "error",
        error: "Notification not found"
      })
    end
  end
end
