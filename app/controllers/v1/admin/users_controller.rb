# app/controllers/v1/admin/users_controller.rb
class V1::Admin::UsersController < V1::ApplicationController
  before_action :super_admin_required!
  LOG_PREFIX = "[Admin::Users]".freeze

  before_action :set_active_user, only: %i[show update discard]
  before_action :set_user_including_discarded, only: :undiscard
  before_action :super_admin_required!, only: %i[
    show
    create
    update
    discard
    undiscard
    read_discarded
  ]

  # GET /users?page=2&limit=25
  def index
    users = search_users(User.includes(:roles))
    users = sort(users, columns: SortConstants::Columns::USER)
    Rails.logger.info("#{LOG_PREFIX} Query: #{users.to_sql}")

    pagy, records = pagy(users)
    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USERS_RETRIEVED),
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/users/discarded?page=1&limit=25
  def read_discarded
    users = search_users(User.with_discarded.discarded.includes(:roles))
    users = sort(users, columns: SortConstants::Columns::USER, default_column: :discarded_at)
    pagy, records = pagy(users)

    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::DISCARDED_USERS_RETRIEVED),
      data: UserSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/users/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_RETRIEVED),
      data: UserSerializer.new(@user).serializable_hash[:data][:attributes]
    )
  end

  # POST /v1/admin/users
  def create
    user = User.new(user_params)
    if user.password.blank?
      temp_passcode = SecureRandom.random_number(10**6).to_s.rjust(6, "0")
      user.password = temp_passcode
      user.password_confirmation = temp_passcode
    end

    if user.save
      assign_roles(user) if role_ids_param_provided?

      render_json_response(
        status_code: 201,
        message: admin_user_message(MessageService::Admin::User::USER_CREATED),
        data: UserSerializer.new(user).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: admin_user_message(MessageService::Admin::User::USER_CREATE_FAILED),
        error: user.errors.full_messages.to_sentence
      )
    end
  end

  # PATCH/PUT /v1/admin/users/:id
  def update
    if @user.update(user_params)
      assign_roles(@user) if role_ids_param_provided?
      assign_avatar(@user) if avatar_param_provided?

      render_json_response(
        status_code: 200,
        message: admin_user_message(MessageService::Admin::User::USER_UPDATED),
        data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: admin_user_message(MessageService::Admin::User::USER_UPDATE_FAILED),
        error: @user.errors.full_messages.to_sentence
      )
    end
  end

  # POST /v1/admin/users/:id/discard
  def discard
    return if protected_lifecycle_user?

    @user.discard!

    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_DISCARDED),
      data: UserSerializer.new(@user).serializable_hash[:data][:attributes]
    )
  end

  # POST /v1/admin/users/:id/undiscard
  def undiscard
    @user.undiscard!

    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_RESTORED),
      data: UserSerializer.new(@user).serializable_hash[:data][:attributes]
    )
  end

  private

  def set_active_user
    @user = User.find(params[:id])
  end

  def set_user_including_discarded
    @user = User.with_discarded.find(params[:id])
  end

  def search_users(scope)
    search = params[:search].to_s.strip
    return scope if search.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
    scope.where(
      "users.username ILIKE :search OR users.name ILIKE :search OR users.email ILIKE :search",
      search: pattern
    )
  end

  def protected_lifecycle_user?
    if @user.id == current_user.id
      render_json_response(
        status_code: 422,
        message: admin_user_message(MessageService::Admin::User::SELF_LIFECYCLE_PROTECTED)
      )
      return true
    end

    return false unless @user.super_admin?
    return false if User.joins(:roles).where(iam_roles: { name: "super_admin" }).count > 1

    render_json_response(
      status_code: 422,
      message: admin_user_message(MessageService::Admin::User::LAST_SUPER_ADMIN_PROTECTED)
    )
    true
  end

  def user_params
    params.require(:user).permit(
      :username,
      :name,
      :email
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

  def avatar_param_provided?
    params[:user].respond_to?(:key?) && params[:user].key?(:avatar_asset_id)
  end

  def assign_avatar(user)
    avatar_asset_id = params.dig(:user, :avatar_asset_id)
    if avatar_asset_id.present?
      asset = Asset.find(avatar_asset_id)
      old_avatars = user.assets.where(type: AssetConstants::AssetType::AVATAR).where.not(id: asset.id)
      Asset.purge_and_destroy_all!(old_avatars)
      asset.update!(assetable: user, type: AssetConstants::AssetType::AVATAR)
    else
      Asset.purge_and_destroy_all!(user.assets.where(type: AssetConstants::AssetType::AVATAR))
    end
  end

  def admin_user_message(key, **options)
    MessageService::Admin::User.t(key, **options)
  end
end
