# app/controllers/v1/notifications_controller.rb
class V1::NotificationsController < V1::ApplicationController
  # POST /notifications/push
  def create_push
    user = User.find(params[:user_id])
    type = params[:type] || PushNotiTemplates::CUSTOM

    unless PushNotiTemplates::ALL.include?(type)
      render_json_response(
        status_code: 422,
        message: notification_message(MessageService::Notification::INVALID_PUSH_TYPE),
        error: supported_types_message(PushNotiTemplates::ALL)
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
        title: params[:title] || notification_message(MessageService::Notification::DEFAULT_TITLE),
        message: params[:body] || notification_message(MessageService::Notification::DEFAULT_BODY),
        data: params[:data] || {},
        send_push: true,
        send_socket: false,
        send_email: false
      )
    end

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::PUSH_QUEUED),
      data: { queued: result[:push] != false }
    )
  rescue => e
    render_json_response(
      status_code: 422,
      message: notification_message(MessageService::Notification::PUSH_FAILED),
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
        message: notification_message(MessageService::Notification::INVALID_EMAIL_TYPE),
        error: supported_types_message(MailTemplates::ALL)
      )
      return
    end

    result = case type
    when MailTemplates::CONFIRMATION
      code = user.confirmation_code || user.generate_confirmation_code
      NotificationService.confirmation_email(email: user.email, code: code)
    when MailTemplates::PASSWORD_RESET
      token = user.send_reset_password_instructions
      NotificationService.password_reset_email(email: user.email, token: token)
    else
      NotificationService.email(
        email: user.email,
        subject: params[:subject] || notification_message(MessageService::Notification::DEFAULT_TITLE),
        body: params[:body] || notification_message(MessageService::Notification::DEFAULT_BODY)
      )
    end

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::EMAIL_QUEUED),
      data: { queued: result != false }
    )
  rescue => e
    render_json_response(
      status_code: 422,
      message: notification_message(MessageService::Notification::EMAIL_FAILED),
      error: e.message
    )
  end

  private

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end

  def supported_types_message(types)
    notification_message(
      MessageService::Notification::SUPPORTED_TYPES,
      types: types.join(", ")
    )
  end
end
