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

  private

  def current_user_params
    params.require(:user).permit(:name, :username)
  end

  def user_message(key, **options)
    MessageService::User.t(key, **options)
  end
end
