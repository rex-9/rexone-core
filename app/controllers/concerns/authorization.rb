# app/controllers/concerns/authorization.rb

module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_action!, if: -> { current_user.present? }
  end

  def authorize_action!
    # SUPER ADMIN: Skip all permission checks
    return if current_user.super_admin?

    resource = controller_name.to_sym
    action = action_name.to_sym

    # Generic mapping - works for any resource
    permission_action = case action
    when :index, :show, :history, :recent
      :read
    when :new, :create
      :create
    when :edit, :update
      :update
    when :destroy, :clear
      :delete
    else
      :read
    end

    # Skip authorization for admin controllers (they use their own)
    return if controller_path.start_with?("admin/")

    unless current_user.can?(permission_action, resource)
      render_json_response(
        status_code: 403,
        message: "Unauthorized",
        error: "You don't have permission to #{permission_action} #{resource}"
      )
    end
  end

  def admin_required!
    unless current_user.admin?
      render_json_response(
        status_code: 403,
        message: "Unauthorized",
        error: "Admin access required"
      )
    end
  end

  def super_admin_required!
    unless current_user.super_admin?
      render_json_response(
        status_code: 403,
        message: "Unauthorized",
        error: "Super admin access required"
      )
    end
  end
end
