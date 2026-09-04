# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_action!, if: :authorization_required?
  end

  def authorization_required?
    current_user.present? &&
      !controller_path.start_with?("auth/")
  end

  def admin_api_controller?
    controller_path.start_with?("v1/admin/")
  end

  def authorize_action!
    if admin_api_controller? && !current_user.admin?
      admin_required!
      return
    end

    return if current_user.can?(permission_action, controller_name, admin_scope: admin_api_controller?)

    render_json_response(
      status_code: 403,
      message: common_message(MessageService::Common::UNAUTHORIZED),
      error: common_message(
        MessageService::Common::PERMISSION_DENIED,
        action: permission_action,
        resource: controller_name
      )
    )
  end

  def permission_action
    action = action_name.to_s

    case action
    when /\Acreate_/, /\Anew\z/
      :create
    when /\Aread_/, /\Aindex\z/, /\Ashow\z/
      :read
    when /\Aupdate_/, /\Aedit\z/
      :update
    when /\Adestroy/, /\Adestroy_/, /\Adiscard/, /\Adiscard_/, /\Aundiscard/, /\Aundiscard_/
      :delete
    when "create", "read", "update", "delete"
      action.to_sym
    else
      :read
    end
  end

  def admin_required!
    return if current_user.admin?

    render_json_response(
      status_code: 403,
      message: common_message(MessageService::Common::UNAUTHORIZED),
      error: common_message(MessageService::Common::ADMIN_REQUIRED)
    )
  end

  def super_admin_required!
    return if current_user.super_admin?

    render_json_response(
      status_code: 403,
      message: common_message(MessageService::Common::UNAUTHORIZED),
      error: common_message(MessageService::Common::SUPER_ADMIN_REQUIRED)
    )
  end

  private

  def common_message(key, **options)
    MessageService::Common.t(key, **options)
  end
end
