class Notification::DispatchJob < ApplicationJob
  queue_as :notifications

  def perform(audience:, channels:, title:, message:, data: {})
    recipients(audience.symbolize_keys).find_each do |user|
      NotificationService.notify(
        user_id: user.id,
        user_email: user.email,
        title: title,
        message: message,
        data: data,
        send_socket: channels.include?("socket"),
        send_push: channels.include?("push"),
        send_email: channels.include?("email")
      )
    end
  end

  private

  def recipients(audience)
    users = User.where.not(confirmed_at: nil)
    return users if audience[:type] == "all"

    users.joins(:roles).where(iam_roles: { id: audience[:role_ids] }).distinct
  end
end
