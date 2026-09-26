# app/controllers/auth/passwords_controller.rb
class Auth::PasswordsController < Devise::PasswordsController
  respond_to :json

  skip_before_action :enforce_active_platform_session!

  # POST /password/forgot
  def create
    email = forgot_password_params[:email].to_s.strip.downcase
    user = User.with_discarded.find_by(email: email)
    if user
      return render_discarded_account if user.discarded?

      limiter = PasswordService.new(user.id)
      unless limiter.reset_allowed?
        remaining = limiter.reset_cooldown_remaining
        return render_json_response(
          status_code: 429,
          meta: { cooldown_remaining: remaining },
          message: auth_message(MessageService::Auth::PASSWORD_RESET_COOLDOWN, seconds: remaining),
          error: auth_message(MessageService::Auth::PASSWORD_RESET_COOLDOWN, seconds: remaining)
        )
      end

      token = user.send_reset_password_instructions
      NotificationService::Center.password_reset_email(
        email: user.email,
        token: token
      )

      limiter.record_reset_request

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
      PasswordService.new(user.id).record_reset_success

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
    redirect_to "#{AppConfig::CLIENT_BASE_URL}#{AuthConstants::ClientRoutes::PASSWORD_RESET}?reset_password_token=#{edit_password_params[:reset_password_token]}", allow_other_host: true
  end

  private

  def auth_message(key, **options)
    MessageService::Auth.t(key, **options)
  end

  def render_discarded_account
    render_json_response(
      status_code: 403,
      message: auth_message(MessageService::Auth::ACCOUNT_DISCARDED),
      error: auth_message(MessageService::Auth::ACCOUNT_DISCARDED)
    )
  end

  def reset_password_params
    params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
  end

  def forgot_password_params
    params.permit(:email)
  end

  def edit_password_params
    params.permit(:reset_password_token)
  end
end
