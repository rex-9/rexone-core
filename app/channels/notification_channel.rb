# app/channels/notification_channel.rb

class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user_#{current_user.id}_notifications"
  end

  def unsubscribed
    # Cleanup if needed
  end
end
