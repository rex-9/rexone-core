# app/controllers/auth/passwords_controller.rb
class Auth::PasswordsController < Devise::PasswordsController
  respond_to :json

  # POST /password/forgot
  def create
    email = params[:email].to_s.strip.downcase
    user = User.with_discarded.find_by(email: email)
    if user
      return render_discarded_account if user.discarded?

      token = user.send_reset_password_instructions
      NotificationService::Center.password_reset_email(
        email: user.email,
        token: token
      )

      render_json_response(
        status_code: 200,
        message: auth_message(
          MessageService::Auth::PASSWORD_RESET_QUEUED,
          email: user.email
        )
      )
    else
      render_json_response(
        status_code: 404,
        message: auth_message(MessageService::Auth::EMAIL_NOT_FOUND),
        error: auth_message(MessageService::Auth::EMAIL_NOT_FOUND)
      )
    end
  end

  # PUT /password/reset
  def update
    user = User.reset_password_by_token(reset_password_params)
    if user.errors.empty?
      render_json_response(
        status_code: 200,
        message: auth_message(MessageService::Auth::PASSWORD_RESET)
      )
    else
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::PASSWORD_RESET_FAILED),
        error: user.errors.full_messages.uniq.to_sentence
      )
    end
  end

  # GET /password/edit?reset_password_token=abcdef
  def edit
    redirect_to "#{AppConfig::CLIENT_BASE_URL}#{AuthConstants::ClientRoutes::PASSWORD_RESET}?reset_password_token=#{params[:reset_password_token]}", allow_other_host: true
  end

  private

  def auth_message(key, **options)
    MessageService::Auth.t(key, **options)
  end

  def render_discarded_account
    render_json_response(
      status_code: 403,
      message: auth_message(MessageService::Auth::PASSWORD_RESET_FAILED),
      error: auth_message(MessageService::Auth::ACCOUNT_DISCARDED)
    )
  end

  def reset_password_params
    params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
  end
end
