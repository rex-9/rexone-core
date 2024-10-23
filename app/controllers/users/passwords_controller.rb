class Users::PasswordsController < Devise::PasswordsController
  respond_to :json

  # POST /password/forgot
  def create
    user = User.find_by(email: params[:email])
    if user
      user.send_reset_password_instructions
      render_json_response(
        status_code: 200,
        message: Messages::PASSWORD_RESET_INSTRUCTIONS_SENT.call(user.email)
      )
    else
      render_json_response(
        status_code: 404,
        message: Messages::EMAIL_NOT_FOUND,
        error: Messages::EMAIL_NOT_FOUND
      )
    end
  end

  # PUT /password/reset
  def update
    user = User.reset_password_by_token(reset_password_params)
    if user.errors.empty?
      render_json_response(
        status_code: 200,
        message: Messages::PASSWORD_RESET_SUCCESSFULLY
      )
    else
      render_json_response(
        status_code: 422,
        message: Messages::FAILED_TO_RESET_PASSWORD,
        error: user.errors.full_messages.uniq.to_sentence
      )
    end
  end

  # GET /password/edit?reset_password_token=abcdef
  def edit
    redirect_to AppConfig::CLIENT_BASE_URL +  "/password/reset?reset_password_token=#{params[:reset_password_token]}", allow_other_host: true
  end

  private

  def reset_password_params
    params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
  end
end
