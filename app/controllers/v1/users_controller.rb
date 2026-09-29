# app/controllers/v1/users_controller.rb
class V1::UsersController < V1::ApplicationController
  LOG_PREFIX = "[Users]".freeze

  skip_before_action :authorize_action!

  # GET /users/current
  def read_current_user
    if current_user
      render_json_response(
        status_code: 200,
        message: user_message(MessageService::User::CURRENT_FETCHED),
        data: UserSerializer.record(current_user)
      )
    else
      render_json_response(
        status_code: 401,
        message: user_message(MessageService::User::NOT_AUTHENTICATED),
        error: user_message(MessageService::User::CURRENT_NOT_FOUND)
      )
    end
  end

  # PUT /users/current
  def update_current_user
    if current_user.update(current_user_params)
      render_json_response(
        status_code: 200,
        message: user_message(MessageService::User::CURRENT_UPDATED),
        data: UserSerializer.record(current_user)
      )
    else
      render_json_response(
        status_code: 422,
        message: user_message(MessageService::User::CURRENT_UPDATE_FAILED),
        error: current_user.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /users/current
  def discard_current_user
    if current_user.super_admin?
      return render_json_response(
        status_code: 422,
        message: user_message(MessageService::User::SUPER_ADMIN_CANNOT_DELETE)
      )
    end

    user = current_user
    if user.discard
      user.update_column(:jti, SecureRandom.uuid)
      AuthConstants::Session.clear_all(user.id)
      SocketService::Client.broadcast(
        user_id: user.id,
        message: user_message(MessageService::User::ACCOUNT_DELETED),
        data: { type: NotificationConstants::NotificationType::SESSION_INVALIDATED }
      )

      render_json_response(
        status_code: 200,
        message: user_message(MessageService::User::ACCOUNT_DELETED),
        data: UserSerializer.record(user)
      )
    else
      render_json_response(
        status_code: 422,
        message: user_message(MessageService::User::ACCOUNT_DELETE_FAILED),
        error: user.errors.full_messages.to_sentence
      )
    end
  end

  private

  def current_user_params
    params.require(:user).permit(:name, :username)
  end

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
