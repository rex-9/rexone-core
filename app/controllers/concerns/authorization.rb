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
    admin_required! if admin_api_controller?

    return if current_user.can?(permission_action, controller_name)

    render_json_response(
      status_code: 403,
      message: "Unauthorized",
      error: "You don't have permission to #{permission_action} #{controller_name}"
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
    when /\Adelete_/, /\Adestroy\z/, /\Adiscard\z/, /\Adiscarded\z/, /\Aundiscard\z/, /\Aundiscarded\z/
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
      message: "Unauthorized",
      error: "Admin access required"
    )
  end

  def super_admin_required!
    return if current_user.super_admin?

    render_json_response(
      status_code: 403,
      message: "Unauthorized",
      error: "Super admin access required"
    )
  end
end
