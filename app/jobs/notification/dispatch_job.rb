# app/jobs/notification/dispatch_job.rb
class Notification::DispatchJob < ApplicationJob
  queue_as :notifications

  def perform(audience:, channels:, event:, locale: I18n.default_locale.to_s)
    I18n.with_locale(locale) do
      notification = Notification.find_by(event: event) || Notification.find_by(id: event)
      return unless notification

      context = (notification.in_app_data || {}).merge("link" => notification.link).compact

      recipients(audience.symbolize_keys).find_each do |user|
        title = notification.render_text(notification.in_app_title.presence || notification.name, user: user, context: context)
        message = notification.render_text(notification.in_app_body, user: user, context: context)
        push_title = notification.render_text(notification.push_title.presence || notification.name, user: user, context: context)
        push_body = notification.render_text(notification.push_body, user: user, context: context)
        email_subject = notification.render_text(notification.email_subject.presence || notification.name, user: user, context: context)
        email_body = notification.render_text(notification.email_body, user: user, context: context)

        email_data = {
          title: email_subject,
          message: email_body,
          subject: email_subject,
          body: email_body,
          user_name: user.name || user.username
        }
        if notification.link.present?
          email_link = AppConfig.client_url(notification.link)
          email_data[:link] = email_link
          email_data[:cta_url] = email_link
        end
        email_data.merge!((notification.in_app_data || {}).symbolize_keys)

        NotificationService::Center.notify(
          user_id: user.id,
          user_email: user.email,
          template_id: notification.id,
          title: title,
          message: message,
          push_title: push_title,
          push_body: push_body,
          link: notification.link,
          clients: notification.clients,
          data: { type: notification.event }.merge(notification.in_app_data || {}),
          send_socket: channels.include?(NotificationConstants::Channel::SOCKET),
          send_push: channels.include?(NotificationConstants::Channel::PUSH),
          send_email: channels.include?(NotificationConstants::Channel::EMAIL),
          push_template_id: notification.push_template_id,
          email_template: notification.email_template_id,
          email_template_data: email_data.compact
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
