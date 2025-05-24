class Users::RegistrationsController < Devise::RegistrationsController
  include RackSessionFix
  respond_to :json

  before_action :check_email_provider, only: [ :create ]

  private

  def sign_up_params
    params.require(:user).permit(:username, :name, :email, :password, :password_confirmation)
  end

  def check_email_provider
    user = User.find_by(email: params[:user][:email])
    if user && user.provider == "google"
      render_json_response(
        status_code: 422,
        message: Messages::USER_ALREADY_REGISTERED_WITH_GOOGLE.call(user.email)
      )
    end
  end

  def respond_with(resource, _opts = {})
    if request.method == "POST" && resource.persisted?
      resource.provider = "email"
      resource.save
      render_json_response(
        status_code: 201,
        message: Messages::SIGNED_UP_SUCCESSFULLY,
        data: { user: UserSerializer.new(resource).serializable_hash[:data][:attributes] }
      )
    elsif request.method == "DELETE"
      render_json_response(
        status_code: 200,
        message: Messages::ACCOUNT_DELETED_SUCCESSFULLY
      )
    else
      render_json_response(
        status_code: 422,
        message: resource.errors.full_messages.uniq.to_sentence
      )
    end
  end

  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
