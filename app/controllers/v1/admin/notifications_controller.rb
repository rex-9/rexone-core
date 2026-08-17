class V1::Admin::NotificationsController < V1::ApplicationController
  # GET /v1/admin/notifications/recipients
  def read_recipients
    users = User.order(:email)

    render_json_response(
      status_code: 200,
      message: notification_message(MessageService::Notification::RECIPIENTS_FETCHED),
      data: UserSerializer.new(users).serializable_hash[:data]
    )
  end

  # POST /v1/admin/notifications
  def create
    return render_invalid_request if request_error

    job = Notification::DispatchJob.perform_later(
      audience: audience,
      channels: channels,
      title: params[:title],
      message: params[:message],
      data: notification_data
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
      value[:role_ids] = Array(raw_audience[:role_ids]).uniq if raw_audience[:type] == "roles"
      value
    else
      {}
    end
  end

  def channels
    @channels ||= params[:channels].is_a?(Array) ? params[:channels].map(&:to_s).uniq : []
  end

  def notification_data
    params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
  end

  def request_error
    return MessageService::Notification::TITLE_REQUIRED if params[:title].blank?
    return MessageService::Notification::MESSAGE_REQUIRED if params[:message].blank?
    return MessageService::Notification::CHANNEL_REQUIRED if channels.empty?
    return MessageService::Notification::INVALID_CHANNEL if (channels - NotificationService::CHANNELS).any?
    return MessageService::Notification::INVALID_AUDIENCE unless audience[:type].in?(NotificationService::AUDIENCES)
    return MessageService::Notification::ROLE_IDS_REQUIRED if audience[:type] == "roles" && audience[:role_ids].blank?
    return MessageService::Notification::INVALID_DATA if params[:data].present? && !params[:data].is_a?(ActionController::Parameters)
    return MessageService::Notification::NO_RECIPIENTS if recipient_count.zero?

    nil
  end

  def recipient_count
    return @recipient_count if defined?(@recipient_count)

    @recipient_count = recipients.count
  end

  def recipients
    users = User.where.not(confirmed_at: nil)
    return users if audience[:type] == "all"

    users.joins(:roles).where(iam_roles: { id: audience[:role_ids] }).distinct
  end

  def render_invalid_request
    render_json_response(
      status_code: 422,
      message: notification_message(MessageService::Notification::INVALID_REQUEST),
      error: notification_message(request_error, channels: NotificationService::CHANNELS.join(", "))
    )
  end

  def notification_message(key, **options)
    MessageService::Notification.t(key, **options)
  end
end
