# app/controllers/v1/notifications_controller.rb
class V1::NotificationsController < V1::ApplicationController
  # GET /v1/notifications
  def index
    scope = current_user.user_notifications.kept.recent

    case params[:filter].to_s.downcase
    when "unread"
      scope = scope.unread
    when "read"
      scope = scope.read_scope
    end

    pagy, records = pagy(:offset, scope, limit: params[:limit] || 20)

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATIONS_FETCHED),
      data: UserNotificationSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/notifications/unread_count
  def read_unread_count
    count = current_user.user_notifications.kept.unread.count

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::UNREAD_COUNT_FETCHED),
      data: { unread_count: count }
    )
  end

  # PUT /v1/notifications/:id/read
  def update_read
    notification = current_user.user_notifications.kept.find(params[:id])
    notification.mark_as_read!

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::MARKED_AS_READ),
      data: UserNotificationSerializer.new(notification).serializable_hash[:data]
    )
  end

  # PUT /v1/notifications/read_all
  def update_read_all
    unread_scope = current_user.user_notifications.kept.unread
    counts_by_notif = unread_scope.where.not(notification_id: nil).group(:notification_id).count
    unread_scope.update_all(read_at: Time.current, updated_at: Time.current)

    counts_by_notif.each do |nid, count|
      Notification.unscoped.where(id: nid).update_all("read_count = COALESCE(read_count, 0) + #{count.to_i}")
    end

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::ALL_MARKED_AS_READ),
      data: { unread_count: 0 }
    )
  end

  # DELETE /v1/notifications/:id
  def destroy
    notification = current_user.user_notifications.kept.find(params[:id])
    notification.discard

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATION_DELETED),
      data: { id: notification.id }
    )
  end

  private

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end
end
