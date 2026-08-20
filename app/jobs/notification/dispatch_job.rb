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
        send_socket: channels.include?(NotificationConstants::Channel::SOCKET),
        send_push: channels.include?(NotificationConstants::Channel::PUSH),
        send_email: channels.include?(NotificationConstants::Channel::EMAIL)
      )
    end
  end

  private

  def recipients(audience)
    users = User.where.not(confirmed_at: nil)
    return users if audience[:type] == NotificationConstants::AudienceType::ALL

    users.joins(:roles).where(iam_roles: { id: audience[:role_ids] }).distinct
  end
end
