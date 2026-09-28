# frozen_string_literal: true

# app/controllers/v1/admin/iam/user_roles_controller.rb
class V1::Admin::Iam::UserRolesController < V1::ApplicationController
  before_action :super_admin_required!
  before_action :set_user_and_role, only: %i[create destroy]

  # GET /v1/admin/iam/users/:user_id/roles
  # GET /v1/admin/iam/roles/:role_id/users
  def index
    if params[:user_id].present?
      user = User.find(params[:user_id])
      roles = user.roles.order(:name)
      pagy, records = pagy(roles, limit: index_params[:limit])

      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::USER_ROLES_FETCHED),
        **::Iam::RoleSerializer.collection_pagy(records, pagy)
      )
    elsif params[:role_id].present?
      role = ::Iam::Role.find(params[:role_id])
      users = role.users.order(:created_at)
      pagy, records = pagy(users, limit: index_params[:limit])

      render_json_response(
        status_code: 200,
        message: admin_user_message(MessageService::Admin::User::USERS_RETRIEVED),
        **UserSerializer.collection_pagy(records, pagy)
      )
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  # POST /v1/admin/iam/users/:user_id/roles
  # POST /v1/admin/iam/roles/:role_id/users
  def create
    user_role = ::Iam::UserRole.find_or_initialize_by(user: @user, role: @role)
    role_changed = user_role.new_record?
    user_role.save!

    if role_changed
      @user.update_column(:jti, SecureRandom.uuid) unless @user.id == current_user&.id
      NotificationService::Center.iam_updated(@user)
    end

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_ASSIGNED),
      data: ::Iam::UserRoleSerializer.record(user_role)
    )
  end

  # DELETE /v1/admin/iam/users/:user_id/roles/:role_id
  # DELETE /v1/admin/iam/roles/:role_id/users/:user_id
  def destroy
    user_role = ::Iam::UserRole.find_by(user: @user, role: @role)

    unless user_role
      return render_json_response(
        status_code: 404,
        message: iam_message(MessageService::Iam::USER_ROLE_NOT_FOUND),
        error: iam_message(MessageService::Iam::USER_ROLE_MISSING)
      )
    end

    if @role.name == IamConstants::Role::SUPER_ADMIN
      removed = @role.with_lock do
        if @role.users.count <= 1
          render_json_response(
            status_code: 422,
            message: iam_message(MessageService::Iam::LAST_SUPER_ADMIN_ROLE_PROTECTED)
          )
          false
        else
          user_role.destroy!
          true
        end
      end
      return unless removed
    else
      user_role.destroy!
    end

    @user.update_column(:jti, SecureRandom.uuid) unless @user.id == current_user&.id
    NotificationService::Center.iam_updated(@user)

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_REMOVED)
    )
  end

  private

  def set_user_and_role
    user_id = params[:user_id].presence || (params[:user_role] && params[:user_role][:user_id]) || user_role_params[:user_id]
    role_id = params[:role_id].presence || (params[:user_role] && params[:user_role][:role_id]) || user_role_params[:role_id]

    raise ActiveRecord::RecordNotFound, iam_message(MessageService::Iam::USER_ROLE_MISSING) unless user_id.present? && role_id.present?

    @user = User.find(user_id)
    @role = ::Iam::Role.find(role_id)
  end

  def index_params
    params.permit(:limit, :page)
  end

  def user_role_params
    params.permit(:user_id, :role_id)
  end

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end

  def admin_user_message(key, **options)
    MessageService::Admin::User.t(key, **options)
  end
end
