# app/controllers/auth/registrations_controller.rb
class Auth::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  before_action :check_email_provider, only: [ :create ]

  private

  def sign_up_params
    params.require(:user).permit(:username, :name, :email, :password, :password_confirmation)
  end

  def check_email_provider
    email = params.dig(:user, :email).to_s.strip.downcase
    return if email.blank?

    user = User.find_by(email: email)
    if user && user.provider == AuthConstants::Provider::GOOGLE
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::SIGN_UP_FAILED),
        error: auth_message(
          MessageService::Auth::GOOGLE_ACCOUNT_EXISTS,
          email: user.email
        )
      )
    end
  end

  def respond_with(resource, _opts = {})
    if request.method == "POST" && resource.persisted?
      resource.provider = AuthConstants::Provider::EMAIL

      # Save resource first, then assign role
      if resource.save
        # The after_create callback will assign the default role
        render_json_response(
          status_code: 201,
          message: auth_message(MessageService::Auth::SIGNED_UP),
          data: { user: UserSerializer.new(resource).serializable_hash[:data][:attributes] }
        )
      else
        render_json_response(
          status_code: 422,
          message: auth_message(MessageService::Auth::SIGN_UP_FAILED),
          error: resource.errors.full_messages.uniq.to_sentence
        )
      end
    elsif request.method == "DELETE"
      render_json_response(
        status_code: 200,
        message: auth_message(MessageService::Auth::ACCOUNT_DELETED)
      )
    else
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::SIGN_UP_FAILED),
        error: resource.errors.full_messages.uniq.to_sentence
      )
    end
  end

  def auth_message(key, **options)
    MessageService::Auth.t(key, **options)
  end
end
