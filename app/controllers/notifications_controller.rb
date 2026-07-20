# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def push
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
      PushNotiService::Client.welcome(user_id: user.id, name: user.name || user.username)
    when PushNotiTemplates::SIGN_IN_ALERT
      PushNotiService::Client.sign_in_alert(user_id: user.id, name: user.name || user.username)
    else
      PushNotiService::Client.send_to_user(
        user_id: user.id,
        title: params[:title] || "Notification",
        body: params[:body] || "You have a new notification.",
        data: params[:data] || {}
      )
    end

    render_json_response(
      status_code: 200,
      message: "Push notification sent.",
      data: { delivered: result != false }
    )
  rescue => e
    render_json_response(
      status_code: 422,
      message: "Failed to send notification.",
      error: e.message
    )
  end

  def email
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
      EmailService::Client.send_email(
        to: user.email,
        subject: Messages::EMAIL_CONFIRMATION_SUBJECT,
        body: Messages::EMAIL_CONFIRMATION_BODY.call(code: code, email: user.email)
      )
    when MailTemplates::PASSWORD_RESET
      user.send_reset_password_instructions
      EmailService::Client.send_email(
        to: user.email,
        subject: Messages::EMAIL_PASSWORD_RESET_SUBJECT,
        body: Messages::EMAIL_PASSWORD_RESET_BODY.call(email: user.email)
      )
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
