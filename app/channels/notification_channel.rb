# app/channels/notification_channel.rb

class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notification_user_#{current_user.id}"
  end

  def unsubscribed
    # Cleanup if needed
  end
end
