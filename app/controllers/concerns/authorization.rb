# app/controllers/concerns/authorization.rb

module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_action!, if: -> { current_user.present? }
  end

  def authorize_action!
    # SUPER ADMIN: Skip all permission checks
    # return if current_user.super_admin?

    resource = controller_name.to_sym
    action = action_name.to_sym

    # Map action to permission based on prefix
    permission_action = case action.to_s
    when /\Acreate_/i, /\Anew\z/i, /\Anew_\z/i
      :create
    when /\Aread_/i, /\Aindex\z/i, /\Aindex_\z/i, /\Ashow\z/i, /\Ashow_\z/i, /\Aget/i, /\Aget_/i
      :read
    when /\Aupdate_/i, /\Aedit\z/i, /\Aedit_\z/i
      :update
    when /\Adelete_/i, /\Adestroy\z/i, /\Adestroy_\z/i
      :delete
    else
      # Fallback: check the actual action name if it matches create/read/update/delete
      if %w[create read update delete].include?(action.to_s)
        action.to_sym
      else
        :read
      end
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
