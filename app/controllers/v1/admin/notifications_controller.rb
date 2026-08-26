class V1::Admin::NotificationsController < V1::ApplicationController
  # GET /v1/admin/notifications/templates
  def read_templates
    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::TEMPLATES_FETCHED),
      data: NotificationService::Templates.catalog
    )
  end

  # POST /v1/admin/notifications
  def create
    return render_invalid_request if request_error

    job = Notification::DispatchJob.perform_later(
      audience: audience,
      channels: channels,
      event: params[:event],
      locale: I18n.locale.to_s
    )

    render_json_response(
      status_code: 202,
      message: notification_message(MessageService::Notification::QUEUED),
      data: {
        job_id: job.job_id,
        audience: audience[:type],
        recipient_count: recipient_count,
        channels: channels
      }
    )
  rescue SolidQueue::Job::EnqueueError, ActiveJob::EnqueueError => error
    Rails.error.report(error)
    render_json_response(
      status_code: 503,
      message: notification_message(MessageService::Notification::QUEUE_FAILED),
      error: notification_message(MessageService::Notification::QUEUE_FAILED)
    )
  end

  private

  def audience
    return @audience if defined?(@audience)

    raw_audience = params[:audience]
    @audience = if raw_audience.is_a?(ActionController::Parameters)
      value = { type: raw_audience[:type] }.compact
      value[:user_ids] = Array(raw_audience[:user_ids]).uniq if value[:type] == NotificationConstants::AudienceType::USERS
      value[:role_ids] = Array(raw_audience[:role_ids]).uniq if value[:type] == NotificationConstants::AudienceType::ROLES
      value
    else
      {}
    end
  end

  def channels
    @channels ||= params[:channels].is_a?(Array) ? params[:channels].map(&:to_s).uniq : []
  end

  def request_error
    return MessageService::Notification::EVENT_REQUIRED if params[:event].blank?
    return MessageService::Notification::INVALID_EVENT unless NotificationService::Templates.admin_available?(params[:event])
    return MessageService::Notification::CHANNEL_REQUIRED if channels.empty?
    return MessageService::Notification::INVALID_CHANNEL if (channels - NotificationService::Center::CHANNELS).any?
    return MessageService::Notification::INVALID_AUDIENCE unless audience[:type].in?(NotificationService::Center::AUDIENCES)
    return MessageService::Notification::USER_IDS_REQUIRED if audience[:type] == NotificationConstants::AudienceType::USERS && audience[:user_ids].blank?
    return MessageService::Notification::ROLE_IDS_REQUIRED if audience[:type] == NotificationConstants::AudienceType::ROLES && audience[:role_ids].blank?
    return MessageService::Notification::NO_RECIPIENTS if recipient_count.zero?

    nil
  end

  def recipient_count
    return @recipient_count if defined?(@recipient_count)

    @recipient_count = recipients.count
  end

  def recipients
    users = User.where.not(confirmed_at: nil)
    return users if audience[:type] == NotificationConstants::AudienceType::ALL
    return users.where(id: audience[:user_ids]) if audience[:type] == NotificationConstants::AudienceType::USERS

    users.joins(:roles).where(iam_roles: { id: audience[:role_ids] }).distinct
  end

  def render_invalid_request
    render_json_response(
      status_code: 422,
      message: notification_message(MessageService::Notification::INVALID_REQUEST),
      error: notification_message(request_error, channels: NotificationService::Center::CHANNELS.join(", "))
    )
  end

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end
end
