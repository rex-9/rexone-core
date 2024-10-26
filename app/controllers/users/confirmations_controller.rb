class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    if resource.errors.empty?
      sign_in(resource) # Automatically sign in the user
      redirect_to AppConfig::CLIENT_BASE_URL + "/signin?auth_token=#{resource.jti}", allow_other_host: true
    else
      redirect_to AppConfig::CLIENT_BASE_URL + "/signin?error=#{resource.errors.full_messages.to_sentence}", allow_other_host: true
    end
  end

  # POST /confirmation/resend
  def resend
    user = User.find_by(email: params[:email])
    if user
      if !user.confirmed?
        user.generate_confirmation_code
        user.send_confirmation_instructions
        render_json_response(
          status_code: 200,
          message: Messages::VERIFICATION_EMAIL_SENT.call(user.email)
        )
      else
        render_json_response(
          status_code: 422,
          message: Messages::EMAIL_ALREADY_CONFIRMED,
          error: Messages::EMAIL_ALREADY_CONFIRMED,
        )
      end
    else
      render_json_response(
        status_code: 404,
        message: Messages::USER_NOT_FOUND,
        error: Messages::USER_NOT_FOUND
      )
    end
  end

  # POST /confirmation/confirm_with_code
  def confirm_with_code
    resource = User.find_by(email: params[:email])
    if resource
      if resource.confirm_with_code(params[:confirmation_code])
        sign_in(resource) # Automatically sign in the resource
        render_json_response(
          status_code: 200,
          message: Messages::EMAIL_CONFIRMED_SUCCESSFULLY,
          data: {
            user: resource,
            token: AppConfig::JWT_TOKEN.call(resource)
          }
        )
      else
        render_json_response(
          status_code: 422,
          message: Messages::EMAIL_FAILED_TO_CONFIRM,
          error: resource.errors.full_messages.to_sentence,
        )
      end
    else
      render_json_response(
        status_code: 422,
        message: Messages::EMAIL_FAILED_TO_CONFIRM,
        error: Messages::USER_NOT_FOUND,
      )
    end
  end

  protected

  def after_confirmation_path_for(resource_name, resource)
    AppConfig::CLIENT_BASE_URL + "?auth_token=#{resource.jti}"
  end
end
