class Users::SessionsController < Devise::SessionsController
  include RackSessionFix
  respond_to :json

  # POST /signin
  def create
    user = User.find_by("email = :login_key OR username = :login_key", login_key: params[:user][:login_key])
    # resource = User.find_by(email: params[:login_key]) || User.find_by(username: params[:login_key])
    # resource = User.find_by { email == params[:login_key] || username == params[:login_key] }
    # users = User.arel_table
    # resource = User.where(users[:email].eq(params[:login_key]).or(users[:username].eq(params[:login_key]))).first
    if user
      if user.provider == "email"
        if user.valid_password?(params[:user][:password])
          if user.confirmed?
            render_json_response(
              status_code: 200,
              message: Messages::SIGNED_IN_SUCCESSFULLY,
              data: {
                user: UserSerializer.new(user).serializable_hash[:data][:attributes],
                token: AppConfig::JWT_TOKEN.call(user)
              }
            )
          else
            user.generate_confirmation_code
            if user.send_confirmation_instructions
              render_json_response(
                status_code: 200,
                message: Messages::VERIFICATION_EMAIL_SENT.call(user.email)
              )
            else
              render_json_response(
                status_code: 422,
                message: Messages::FAILED_TO_SEND_VERIFICATION_EMAIL.call(user.email),
                error: user.errors.full_messages.uniq.to_sentence
              )
            end
          end
        else
          render_json_response(
            status_code: 401,
            message: Messages::FAILED_TO_SIGN_IN,
            error: Messages::INVALID_LOGIN_CREDENTIALS
          )
        end
      else
        render_json_response(
          status_code: 401,
          message: Messages::FAILED_TO_SIGN_IN,
          error: Messages::USER_ALREADY_REGISTERED_WITH_GOOGLE.call(user.email)
        )
      end
    else
      render_json_response(
        status_code: 401,
        message: Messages::FAILED_TO_SIGN_IN,
        error: Messages::USER_NOT_FOUND
      )
    end
  end

  # POST /signin/token
  def token_sign_in
    user = User.find_by(jti: params[:token])
    if user
      sign_in(user)
      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: AppConfig::JWT_TOKEN.call(user)
        }
      )
    else
      render_json_response(
        status_code: 401,
        message: Messages::INVALID_AUTHENTICATION_TOKEN,
        error: Messages::INVALID_AUTHENTICATION_TOKEN
      )
    end
  end

  # POST /signin/google
  def google_sign_in
    token = params[:token]
    user_info = get_google_user_info(token)
    if not user_info
      return render_json_response(
        status_code: 401,
        message: Messages::GOOGLE_AUTHENTICATION_FAILED,
        error: Messages::GOOGLE_AUTHENTICATION_FAILED
      )
    end
    user = User.find_by(email: user_info["email"])
    if user
      if user.provider == "google"
        render_json_response(
          status_code: 200,
          message: Messages::SIGNED_IN_SUCCESSFULLY,
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: AppConfig::JWT_TOKEN.call(user)
          }
        )
      else
        render_json_response(
          status_code: 401,
          message: Messages::GOOGLE_AUTHENTICATION_FAILED,
          error: Messages::USER_ALREADY_REGISTERED_WITH_EMAIL.call(user.email)
        )
      end
    else
      sanitized_username = sanitize_email(user_info["email"])
      user = User.create(
        email: user_info["email"],
        username: sanitized_username,
        name: user_info["name"],
        photo: user_info["picture"],
        password: Devise.friendly_token[0, 20],
        provider: "google",
        confirmed_at: Time.now
      )
      if user.save
        render_json_response(
          status_code: 201,
          message: Messages::ACCOUNT_CREATED_AND_SIGNED_IN_SUCCESSFULLY,
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: AppConfig::JWT_TOKEN.call(user)
          }
        )
      else
        render_json_response(
          status_code: 422,
          message: Messages::GOOGLE_AUTHENTICATION_FAILED,
          error: user.errors.full_messages.uniq.to_sentence
        )
      end
    end
  end

  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(resource).serializable_hash[:data][:attributes],
          token: AppConfig::JWT_TOKEN.call(resource)
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: Messages::FAILED_TO_SIGN_IN,
        error: resource.errors.full_messages.uniq.to_sentence
      )
    end
  end

  def respond_to_on_destroy
    if current_user
      current_user.update(jti: SecureRandom.uuid)
      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_OUT_SUCCESSFULLY
      )
    else
      render_json_response(
        status_code: 401,
        message: Messages::FAILED_TO_SIGN_OUT,
        error: Messages::ACTIVE_SESSION_NOT_FOUND
      )
    end
  end

  def get_google_user_info(token)
    response = RestClient.get("https://www.googleapis.com/oauth2/v3/tokeninfo", { params: { id_token: token } })
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("#{Messages::GOOGLE_AUTHENTICATION_FAILED}: #{e.response}")
    nil
  end

  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
