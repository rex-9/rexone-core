# app/controllers/v1/admin/users_controller.rb
class V1::Admin::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Admin::Users]".freeze

  before_action :set_active_user, only: %i[show update discard]
  before_action :set_user_including_discarded, only: :undiscard
  before_action :super_admin_required!, only: %i[
    create
    update
    discard
    undiscard
  ]
  before_action :super_admin_required_for_discarded_index!, only: :index

  # GET /users?page=2&limit=25
  def index
    filters = index_params
    discarded = filters[:discarded].to_s == "true"
    scope = discarded ? User.with_discarded.discarded.includes(:roles) : User.includes(:roles)
    users = search_users(scope, search_term: filters[:search])
    users = if discarded
      sort(users, columns: SortConstants::Columns::USER, default_column: :discarded_at)
    else
      sort(users, columns: SortConstants::Columns::USER)
    end
    Rails.logger.info("#{LOG_PREFIX} Query: #{users.to_sql}")

    pagy, records = pagy(users, limit: filters[:limit])
    render_json_response(
      status_code: 200,
      message: admin_user_message(
        discarded ? MessageService::Admin::User::DISCARDED_USERS_RETRIEVED : MessageService::Admin::User::USERS_RETRIEVED
      ),
      **UserSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/users/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_RETRIEVED),
      data: UserSerializer.record(@user)
    )
  end

  # POST /v1/admin/users
  def create
    user = User.new(user_attributes)
    if user.password.blank?
      temp_passcode = SecureRandom.random_number(10**6).to_s.rjust(6, "0")
      user.password = temp_passcode
      user.password_confirmation = temp_passcode
    end

    if user.save
      assign_avatar(user) if avatar_param_provided?

      render_json_response(
        status_code: 201,
        message: admin_user_message(MessageService::Admin::User::USER_CREATED),
        data: UserSerializer.record(user)
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
    if @user.update(user_attributes)
      assign_avatar(@user) if avatar_param_provided?

      render_json_response(
        status_code: 200,
        message: admin_user_message(MessageService::Admin::User::USER_UPDATED),
        data: UserSerializer.record(@user.reload)
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
      data: UserSerializer.record(@user)
    )
  end

  # POST /v1/admin/users/:id/undiscard
  def undiscard
    @user.undiscard!

    render_json_response(
      status_code: 200,
      message: admin_user_message(MessageService::Admin::User::USER_RESTORED),
      data: UserSerializer.record(@user)
    )
  end

  private

  def index_params
    params.permit(:discarded, :search, :limit, :page)
  end

  def super_admin_required_for_discarded_index!
    super_admin_required! if index_params[:discarded].to_s == "true"
  end

  def set_active_user
    @user = User.find(params.permit(:id)[:id])
  end

  def set_user_including_discarded
    @user = User.with_discarded.find(params.permit(:id)[:id])
  end

  def search_users(scope, search_term: nil)
    return scope if search_term.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.to_s.strip)}%"
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

    render_json_response(
      status_code: 422,
      message: admin_user_message(MessageService::Admin::User::SUPER_ADMIN_LIFECYCLE_PROTECTED)
    )
    true
  end

  def user_params
    params.require(:user).permit(
      :username,
      :name,
      :email,
      :avatar_asset_id
    )
  end

  def user_attributes
    user_params.except(:avatar_asset_id)
  end

  def avatar_param_provided?
    user_params.key?(:avatar_asset_id)
  end

  def assign_avatar(user)
    avatar_asset_id = user_params[:avatar_asset_id]
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
