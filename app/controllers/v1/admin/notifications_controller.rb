class V1::Admin::NotificationsController < V1::ApplicationController
  # GET /v1/admin/notifications/recipients
  def read_recipients
    users = User.order(:email)

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::USERS_RETRIEVED,
      data: UserSerializer.new(users).serializable_hash[:data]
    )
  end

  # POST /v1/admin/notifications
  def create
    users = User.where(id: user_ids_param)

    unless delivery_channel_selected?
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::NOTIFICATION_SEND_FAILED,
        error: "Select at least one delivery channel."
      )
      return
    end

    if users.empty?
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::NOTIFICATION_SEND_FAILED,
        error: "Select at least one user."
      )
      return
    end

    results = users.index_with do |user|
      NotificationService.custom(
        user_id: user.id,
        title: notification_params[:title],
        message: notification_params[:message],
        data: { type: "admin_notification" },
        send_push: truthy_param?(notification_params[:send_push]),
        send_socket: truthy_param?(notification_params[:send_socket]),
        send_email: truthy_param?(notification_params[:send_email])
      )
    end

    failures = results.select { |_user, result| result[:error].present? }

    if failures.any?
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::NOTIFICATION_SEND_FAILED,
        error: failures.values.map { |result| result[:error] }.join(", ")
      )
      return
    end

    render_json_response(
      status_code: 201,
      message: AdminApiMessages::NOTIFICATION_SENT,
      data: {
        delivered: {
          count: users.length,
          users: results.transform_keys(&:id)
        }
      }
    )
  end

  private

  def notification_params
    params.require(:notification).permit(
      :title,
      :message,
      :send_push,
      :send_socket,
      :send_email,
      user_ids: []
    )
  end

  def user_ids_param
    Array(notification_params[:user_ids]).reject(&:blank?)
  end

  def delivery_channel_selected?
    truthy_param?(notification_params[:send_push]) ||
      truthy_param?(notification_params[:send_socket]) ||
      truthy_param?(notification_params[:send_email])
  end

  def truthy_param?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
