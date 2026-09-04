# app/controllers/v1/notifications_controller.rb

class V1::NotificationsController < V1::ApplicationController
  skip_before_action :authorize_action!

  # GET /v1/notifications
  def index
    notifications = current_user.notifications.recent
    pagy, records = pagy(:offset, notifications, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::FETCHED),
      data: NotificationSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # PUT /v1/notifications/:id/read
  def update_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::READ),
      data: NotificationSerializer.new(notification).serializable_hash[:data]
    )
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: notification_message(MessageService::Notification::NOT_FOUND),
      error: notification_message(MessageService::Notification::NOT_FOUND)
    )
  end

  # PUT /v1/notifications/read_all
  def update_read_all
    current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::READ_ALL)
    )
  end

  private

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end
end
