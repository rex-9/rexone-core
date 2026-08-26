class Notification::DispatchJob < ApplicationJob
  queue_as :notifications

  def perform(audience:, channels:, event:, locale: I18n.default_locale.to_s)
    I18n.with_locale(locale) do
      template = NotificationService::Templates.render(event)

      recipients(audience.symbolize_keys).find_each do |user|
        NotificationService::Center.notify(
          user_id: user.id,
          user_email: user.email,
          title: template.fetch(:title),
          message: template.fetch(:message),
          data: template.fetch(:data),
          email_template: template.fetch(:email_template),
          email_template_data: template.fetch(:email_template_data).merge(
            user_name: user.name || user.username
          ),
          send_socket: channels.include?(NotificationConstants::Channel::SOCKET),
          send_push: channels.include?(NotificationConstants::Channel::PUSH),
          send_email: channels.include?(NotificationConstants::Channel::EMAIL)
        )
      end
    end
  end

  private

  def recipients(audience)
    users = User.where.not(confirmed_at: nil)
    return users if audience[:type] == NotificationConstants::AudienceType::ALL
    return users.where(id: audience[:user_ids]) if audience[:type] == NotificationConstants::AudienceType::USERS

    users.joins(:roles).where(iam_roles: { id: audience[:role_ids] }).distinct
  end
end
