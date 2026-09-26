# frozen_string_literal: true

# app/controllers/v1/admin/user_notifications_controller.rb
class V1::Admin::UserNotificationsController < V1::ApplicationController
  before_action :set_active_user_notification, only: %i[discard]
  before_action :set_user_notification_including_discarded, only: %i[show undiscard destroy]

  # GET /v1/admin/user_notifications
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    scope = discarded ? UserNotification.with_discarded.discarded : UserNotification.kept
    scope = scope.includes(:user, :notification)

    scope = scope.where(user_id: filters[:user_id]) if filters[:user_id].present?
    scope = scope.for_client(filters[:client]) if filters[:client].present?

    case (filters[:status].presence || filters[:filter]).to_s.downcase
    when "unread"
      scope = scope.unread
    when "read"
      scope = scope.read_scope
    end

    if filters[:search].present?
      q = "%#{filters[:search]}%"
      scope = scope.left_joins(:user).where(
        "user_notifications.title ILIKE :q OR user_notifications.message ILIKE :q OR user_notifications.link ILIKE :q OR users.email ILIKE :q OR users.username ILIKE :q OR users.name ILIKE :q",
        q: q
      )
    end

    default_sort = discarded ? :discarded_at : :created_at
    scope = sort(scope, columns: SortConstants::Columns::USER_NOTIFICATION, default_column: default_sort)

    limit = filters[:limit].presence || 20
    pagy, records = pagy(:offset, scope, limit: limit)

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATIONS_FETCHED),
      **UserNotificationAdminSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/user_notifications/:id
  def show
    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATIONS_FETCHED),
      data: UserNotificationAdminSerializer.record(@user_notification)
    )
  end

  # POST /v1/admin/user_notifications/:id/discard
  def discard
    @user_notification.discard!

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATION_DISCARDED),
      data: UserNotificationAdminSerializer.record(@user_notification)
    )
  end

  # POST /v1/admin/user_notifications/:id/undiscard
  def undiscard
    @user_notification.undiscard!

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATION_UNDISCARDED),
      data: UserNotificationAdminSerializer.record(@user_notification)
    )
  end

  # DELETE /v1/admin/user_notifications/:id
  def destroy
    @user_notification.destroy!

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::NOTIFICATION_DELETED)
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    render_json_response(
      status_code: 422,
      message: notification_message(MessageService::Notification::NOTIFICATION_DELETED),
      error: e.message
    )
  end

  # DELETE /v1/admin/user_notifications/bin
  def destroy_bin
    scope = UserNotification.with_discarded.discarded
    count = scope.count
    scope.destroy_all

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::RECYCLE_BIN_EMPTIED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/user_notifications/discard_batch
  def discard_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED),
        error: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED)
      )
      return
    end

    scope = UserNotification.kept.where(id: ids)
    count = 0
    scope.find_each do |notification|
      count += 1 if notification.discard
    end

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::BATCH_DISCARDED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/user_notifications/undiscard_batch
  def undiscard_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED),
        error: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED)
      )
      return
    end

    scope = UserNotification.with_discarded.discarded.where(id: ids)
    count = 0
    scope.find_each do |notification|
      count += 1 if notification.undiscard
    end

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::BATCH_RESTORED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/user_notifications/destroy_batch
  def destroy_batch
    ids = Array(batch_params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED),
        error: notification_message(MessageService::Notification::NO_NOTIFICATIONS_SELECTED)
      )
      return
    end

    scope = UserNotification.with_discarded.where(id: ids)
    count = scope.count
    scope.destroy_all

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::BATCH_DELETED, count: count),
      data: { count: count }
    )
  end

  private

  def set_active_user_notification
    @user_notification = UserNotification.kept.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: notification_message(MessageService::Notification::NOTIFICATION_NOT_FOUND)
    )
  end

  def set_user_notification_including_discarded
    @user_notification = UserNotification.with_discarded.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: notification_message(MessageService::Notification::NOTIFICATION_NOT_FOUND)
    )
  end

  def filter_params
    params.permit(:page, :limit, :user_id, :client, :status, :filter, :search, :sort_by, :sort_order, :discarded)
  end

  def batch_params
    params.permit(ids: [])
  end

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end
end
