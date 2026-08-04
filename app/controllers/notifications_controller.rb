# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  # POST /notifications/push
  def create_push
    user = User.find(params[:user_id])
    type = params[:type] || PushNotiTemplates::CUSTOM

    unless PushNotiTemplates::ALL.include?(type)
      render_json_response(
        status_code: 422,
        message: "Invalid push type.",
        error: "Supported types: #{PushNotiTemplates::ALL.join(', ')}"
      )
      return
    end

    result = case type
    when PushNotiTemplates::WELCOME
      NotificationService.welcome(user_id: user.id, name: user.name || user.username)
    when PushNotiTemplates::SIGN_IN_ALERT
      NotificationService.sign_in_alert(user_id: user.id, name: user.name || user.username)
    else
      NotificationService.custom(
        user_id: user.id,
        title: params[:title] || "Notification",
        message: params[:body] || "You have a new notification.",
        data: params[:data] || {},
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    render_json_response(
      status_code: 200,
      message: "Push notification sent.",
      data: { delivered: result[:push] != false }
    )
  rescue => e
    render_json_response(
      status_code: 422,
      message: "Failed to send notification.",
      error: e.message
    )
  end

  # POST /notifications/email
  def create_email
    user = User.find(params[:user_id])
    type = params[:type] || MailTemplates::CUSTOM

    unless MailTemplates::ALL.include?(type)
      render_json_response(
        status_code: 422,
        message: "Invalid email type.",
        error: "Supported types: #{MailTemplates::ALL.join(', ')}"
      )
      return
    end

    result = case type
    when MailTemplates::CONFIRMATION
      code = user.confirmation_code || user.generate_confirmation_code
      NotificationService.confirmation_email(user_id: user.id, code: code)
    when MailTemplates::PASSWORD_RESET
      user.send_reset_password_instructions
      NotificationService.password_reset_email(user_id: user.id, token: user.reset_password_token)
    else
      EmailService::Client.send_email(
        to: user.email,
        subject: params[:subject] || "Notification",
        body: params[:body] || "You have a new notification."
      )
    end

    render_json_response(
      status_code: 200,
      message: "Email sent.",
      data: { delivered: result != false }
    )
  rescue => e
    render_json_response(
      status_code: 422,
      message: "Failed to send email.",
      error: e.message
    )
  end
end
