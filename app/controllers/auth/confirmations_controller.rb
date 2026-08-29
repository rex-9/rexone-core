# app/controllers/auth/confirmations_controller.rb
class Auth::ConfirmationsController < Devise::ConfirmationsController
  include PlatformSession

  # GET /confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    if resource.errors.empty?
      sign_in(resource) # Auto sign in user
      # Redirect to /email/confirm with auth_token
      redirect_to "#{AppConfig::CLIENT_BASE_URL}/email/confirm?auth_token=#{resource.jti}", allow_other_host: true
    else
      redirect_to "#{AppConfig::CLIENT_BASE_URL}/email/confirm?error=#{resource.errors.full_messages.to_sentence}", allow_other_host: true
    end
  end

  # POST /confirmation/send_code
  def send_code
    user = User.find_by("email = :signin_key OR username = :signin_key", signin_key: params[:signin_key])
    if user
      if !user.confirmed?
        user.send_confirmation_instructions

        render_json_response(
          status_code: 200,
          message: auth_message(
            MessageService::Auth::CONFIRMATION_EMAIL_QUEUED,
            email: user.email
          )
        )
      else
        render_json_response(
          status_code: 422,
          message: auth_message(MessageService::Auth::EMAIL_ALREADY_CONFIRMED),
          error: auth_message(MessageService::Auth::EMAIL_ALREADY_CONFIRMED),
        )
      end
    else
        render_json_response(
        status_code: 404,
        message: auth_message(MessageService::Auth::USER_NOT_FOUND),
        error: auth_message(MessageService::Auth::USER_NOT_FOUND)
      )
    end
  end

  # POST /confirmation/confirm_code
  def confirm_code
    resource = User.find_by("email = :signin_key OR username = :signin_key", signin_key: params[:signin_key])
    if resource
      if resource.confirm_code(params[:confirmation_code])
        sign_in(resource) # Automatically sign in the resource
        token = AppConfig::JWT_TOKEN.call(resource)
        signup_active_session!(user: resource, token: token)
        NotificationService::Center.welcome(
          user_id: resource.id,
          name: resource.name || resource.username
        )
        render_json_response(
          status_code: 200,
          message: auth_message(MessageService::Auth::EMAIL_CONFIRMED),
          data: {
            user: resource,
            token: token
          }
        )
      else
        render_json_response(
          status_code: 422,
          message: auth_message(MessageService::Auth::EMAIL_CONFIRMATION_FAILED),
          error: resource.errors.full_messages.to_sentence,
        )
      end
    else
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::EMAIL_CONFIRMATION_FAILED),
        error: auth_message(MessageService::Auth::USER_NOT_FOUND),
      )
    end
  end

  protected

  def auth_message(key, **options)
    MessageService::Auth.t(key, **options)
  end



  def signup_active_session!(user:, token:)
    key = "active_session:user:#{user.id}:#{platform_session}"
    CacheService.write(key, token, expires_in: AppConfig::SESSION_TIMEOUT)
  rescue => e
    Rails.logger.error("#{ApplicationController::AUTH_LOG_PREFIX} Failed to sign up active session: #{e.message}")
  end

  def after_confirmation_path_for(resource_name, resource)
    AppConfig::CLIENT_BASE_URL + "?auth_token=#{resource.jti}"
  end
end
