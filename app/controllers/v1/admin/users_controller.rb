# app/controllers/v1/admin/users_controller.rb
class V1::Admin::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Admin::Users]".freeze

  before_action :set_user, only: %i[show update destroy]

  # GET /users?page=2&limit=25
  def index
    users = User.includes(:roles).order(created_at: :desc)
    Rails.logger.info("#{LOG_PREFIX} Query: #{users.to_sql}")

    pagy, records = pagy(:offset, users, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::USERS_RETRIEVED,
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/users/roles
  def read_roles
    roles = Iam::Role.includes(:permissions).order(:name)

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::USER_ROLES_RETRIEVED,
      data: {
        roles: Iam::RoleSerializer.new(roles).serializable_hash[:data]
      }
    )
  end

  # GET /v1/admin/users/:id
  def show
    render_json_response(
      status_code: 200,
      message: AdminApiMessages::USER_RETRIEVED,
      data: {
        user: UserSerializer.new(@user).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /v1/admin/users
  def create
    user = User.new(user_params)

    if user.save
      assign_roles(user) if role_ids_param_provided?

      render_json_response(
        status_code: 201,
        message: AdminApiMessages::USER_CREATED,
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::USER_CREATE_FAILED,
        error: user.errors.full_messages.to_sentence
      )
    end
  end

  # PATCH/PUT /v1/admin/users/:id
  def update
    if @user.update(user_params)
      assign_roles(@user) if role_ids_param_provided?

      render_json_response(
        status_code: 200,
        message: AdminApiMessages::USER_UPDATED,
        data: {
          user: UserSerializer.new(@user).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::USER_UPDATE_FAILED,
        error: @user.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /v1/admin/users/:id
  def destroy
    @user.destroy

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::USER_DELETED
    )
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :username,
      :name,
      :email,
      :password,
      :password_confirmation
    )
  end

  def role_ids_param
    params.dig(:user, :role_ids)
  end

  def role_ids_param_provided?
    params[:user].respond_to?(:key?) && params[:user].key?(:role_ids)
  end

  def assign_roles(user)
    role_ids = Array(role_ids_param).reject(&:blank?)
    roles = Iam::Role.where(id: role_ids)

    user.user_roles.destroy_all
    roles.each do |role|
      user.user_roles.find_or_create_by!(role: role)
    end
  end
end
