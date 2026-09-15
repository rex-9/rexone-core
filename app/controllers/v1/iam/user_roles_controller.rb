# app/controllers/v1/iam/user_roles_controller.rb
class V1::Iam::UserRolesController < V1::ApplicationController
  before_action :super_admin_required!

  # GET /iam/user_roles?user_id=:user_id&page=1&limit=10
  # Returns all roles assigned to a specific user
  def index
    user = User.find(index_params[:user_id])
    roles = user.roles
    pagy, records = pagy(:offset, roles, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::USER_ROLES_FETCHED),
      data: Iam::RoleSerializer.paginated(records, pagy).merge(user_id: user.id),
      pagy: pagy
    )
  end

  # POST /iam/user_roles?user_id=:user_id&role_id=:role_id
  # Assigns a role to a user
  def create
    user = User.find(user_role_params[:user_id])
    role = Iam::Role.find(user_role_params[:role_id])

    user_role = Iam::UserRole.find_or_initialize_by(user: user, role: role)
    role_changed = user_role.new_record?
    user_role.save!
    NotificationService::Center.iam_updated(user) if role_changed

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_ASSIGNED),
      data: {
        user_role: Iam::UserRoleSerializer.new(user_role).serializable_hash[:data][:attributes]
      }
    )
  end

  # DELETE /iam/user_roles?user_id=:user_id&role_id=:role_id
  # Removes a role from a user
  def destroy
    user = User.find(user_role_params[:user_id])
    role = Iam::Role.find(user_role_params[:role_id])

    user_role = Iam::UserRole.find_by(user: user, role: role)

    if user_role
      if role.name == IamConstants::Role::SUPER_ADMIN
        removed = role.with_lock do
          if role.users.count <= 1
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

      NotificationService::Center.iam_updated(user)
      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::ROLE_REMOVED)
      )
    else
      render_json_response(
        status_code: 404,
        message: iam_message(MessageService::Iam::USER_ROLE_NOT_FOUND),
        error: iam_message(MessageService::Iam::USER_ROLE_MISSING)
      )
    end
  end

  private

  def index_params
    params.permit(:user_id, :limit, :page)
  end

  def user_role_params
    params.permit(:user_id, :role_id)
  end

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end
end
