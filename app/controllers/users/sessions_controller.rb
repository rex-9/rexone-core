class Users::SessionsController < Devise::SessionsController
  respond_to :json

  skip_before_action :enforce_active_platform_session!, only: [ :create, :token_sign_in, :google_sign_in, :google_sign_in_complete ]
  skip_before_action :require_no_authentication, only: [ :google_sign_in, :google_sign_in_complete ]

  # POST /signin
  def create
    user = User.find_by("email = :signin_key OR username = :signin_key", signin_key: params[:user][:signin_key])

    if user.nil?
      render_json_response(
        status_code: 401,
        message: Messages::FAILED_TO_SIGN_IN,
        error: Messages::USER_NOT_FOUND
      )
      return
    end

    limiter = PasswordAttemptService.new(user.id)
    unless limiter.allowed?
      render_json_response(
        status_code: 429,
        message: Messages::FAILED_TO_SIGN_IN,
        error: "Too many attempts. Please wait #{limiter.cooldown_remaining} seconds.",
        data: {
          remaining_attempts: 0,
          cooldown_remaining: limiter.cooldown_remaining
        }
      )
      return
    end

    if user.valid_password?(params[:user][:password])
      limiter.record_success

      if user.confirmed?
        token = AppConfig::JWT_TOKEN.call(user)
        signup_active_session!(user: user, token: token)

        render_json_response(
          status_code: 200,
          message: Messages::SIGNED_IN_SUCCESSFULLY,
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: token,
            remaining_attempts: 3,
            cooldown_remaining: 0
          }
        )
      else
        user.generate_confirmation_code
        user.send_confirmation_instructions

        render_json_response(
          status_code: 200,
          message: Messages::VERIFICATION_EMAIL_SENT.call(user.email),
          data: { otp_sent: true }
        )
      end
    else
      failure_data = limiter.record_failure

      render_json_response(
        status_code: failure_data[:cooldown_active] ? 429 : 401,
        message: Messages::FAILED_TO_SIGN_IN,
        error: failure_data[:cooldown_active] ? "Too many attempts" : Messages::INVALID_SIGNIN_CREDENTIALS,
        data: {
          remaining_attempts: failure_data[:remaining_attempts],
          cooldown_remaining: failure_data[:cooldown_remaining] || 0
        }
      )
    end
  end

  # POST /signin/token
  def token_sign_in
    user = User.find_by(jti: params[:token])
    if user
      sign_in(user)
      token = AppConfig::JWT_TOKEN.call(user)
      signup_active_session!(user: user, token: token)

      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: token
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

    if !user_info || user_info["email"].blank?
      render_json_response(
        status_code: 401,
        message: Messages::GOOGLE_AUTHENTICATION_FAILED,
        error: Messages::GOOGLE_AUTHENTICATION_FAILED
      )
      return
    end

    user = User.find_by(email: user_info["email"])

    if user
      token = AppConfig::JWT_TOKEN.call(user)
      signup_active_session!(user: user, token: token)

      # Existing user - just return user + token
      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: token
        }
      )
      return
    end

    # New user - return challenge token
    challenge_token = SecureRandom.urlsafe_base64(32)

    challenge_payload = {
      email: user_info["email"],
      name: user_info["name"],
      picture: user_info["picture"]
    }

    store_google_challenge!(challenge_token, challenge_payload)

    render_json_response(
      status_code: 200,
      message: "Set a passcode to complete account creation.",
      data: {
        password_required: true,
        challenge_token: challenge_token
      }
    )
  end

  # POST /signin/google/complete
  def google_sign_in_complete
    challenge_token = params[:challenge_token]
    password = params[:password].presence || params[:password].presence

    if challenge_token.blank? || password.blank?
      render_json_response(
        status_code: 422,
        message: Messages::FAILED_TO_SIGN_IN,
        error: "Challenge token and passcode are required."
      )
      return
    end

    challenge_data = fetch_google_challenge(challenge_token)
    if challenge_data.blank?
      render_json_response(
        status_code: 401,
        message: Messages::INVALID_AUTHENTICATION_TOKEN,
        error: Messages::INVALID_AUTHENTICATION_TOKEN
      )
      return
    end

    user = User.find_by(email: challenge_data["email"])

    # If user already exists (shouldn't happen, but handle gracefully)
    if user
      clear_google_challenge!(challenge_token)
      token = AppConfig::JWT_TOKEN.call(user)
      signup_active_session!(user: user, token: token)

      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: token
        }
      )
      return
    end

    # Create new Google user
    sanitized_username = sanitize_email(challenge_data["email"])
    user = User.create(
      email: challenge_data["email"],
      username: sanitized_username,
      name: challenge_data["name"],
      password: password,
      provider: "google",
      confirmed_at: Time.now
    )

    unless user.save
      render_json_response(
        status_code: 422,
        message: Messages::GOOGLE_AUTHENTICATION_FAILED,
        error: user.errors.full_messages.uniq.to_sentence
      )
      return
    end

    # Save google profile picture
    asset = Asset.create(
      name: "profile_google_of_user_#{user.id}",
      url: challenge_data["picture"],
      category: "profile",
      format: "image",
      size: 0,
      source: "google",
      user: user,
    )

    unless asset.save
      # Log but don't fail the request - user can upload later
      Rails.logger.warn("Failed to save Google profile picture for user #{user.id}: #{asset.errors.full_messages}")

      # render_json_response(
      #   status_code: 422,
      #   message: Messages::FAILED_TO_SAVE_GOOGLE_PHOTO,
      #   error: asset.errors.full_messages.uniq.to_sentence
      # )
      # return
    end

    clear_google_challenge!(challenge_token)

    token = AppConfig::JWT_TOKEN.call(user)
    signup_active_session!(user: user, token: token)

    render_json_response(
      status_code: 201,
      message: Messages::ACCOUNT_CREATED_AND_SIGNED_IN_SUCCESSFULLY,
      data: {
        user: UserSerializer.new(user).serializable_hash[:data][:attributes],
        token: token
      }
    )
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      token = AppConfig::JWT_TOKEN.call(resource)
      signup_active_session!(user: resource, token: token)

      render_json_response(
        status_code: 200,
        message: Messages::SIGNED_IN_SUCCESSFULLY,
        data: {
          user: UserSerializer.new(resource).serializable_hash[:data][:attributes],
          token: token
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

  def destroy
    @user_before_sign_out = current_user
    super
  end

  # Devise's prepend_before_action for destroy calls this to check if the user
  # is already signed out. With JWT, warden state is unreliable at this point
  # (the RevocationManager middleware runs after the response). We skip this
  # check entirely and let our destroy action handle the response.
  def verify_signed_out_user(*_args); end

  def respond_to_on_destroy(*_args)
    if @user_before_sign_out
      clear_active_session!(@user_before_sign_out)

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

  private

  def session_platform
    value = request.headers["X-Platform"].presence || params[:platform].presence || "web"
    %w[web mobile].include?(value) ? value : "web"
  end

  def session_key_for(user_id, platform = session_platform)
    "active_session:user:#{user_id}:#{platform}"
  end

  def signup_active_session!(user:, token:)
    PASSWORD_REDIS.set(session_key_for(user.id), token, ex: AppConfig::SESSION_TIMEOUT.to_i)
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Failed to sign up active session: #{e.message}")
  end

  def clear_active_session!(user)
    token = request.headers["Authorization"].to_s.split(" ").last
    key = session_key_for(user.id)
    active_token = PASSWORD_REDIS.get(key)

    return if active_token.blank?

    if token.present? && active_token == token
      PASSWORD_REDIS.del(key)
    end
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Failed to clear active session: #{e.message}")
  end

  def get_google_user_info(token)
    return nil if token.blank?

    begin
      response = RestClient.get("https://www.googleapis.com/oauth2/v3/tokeninfo", { params: { id_token: token } })
      user_info = JSON.parse(response.body)
      return user_info if user_info["email"].present?
    rescue RestClient::ExceptionWithResponse
      # Not an ID token or token is invalid. Try Google userinfo endpoint as access token.
    end

    response = RestClient.get("https://www.googleapis.com/oauth2/v1/userinfo", { params: { access_token: token, alt: "json" } })
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("#{Messages::GOOGLE_AUTHENTICATION_FAILED}: #{e.response&.body || e.response}")
    nil
  end

  def google_challenge_key(challenge_token)
    "google_signin:challenge:#{challenge_token}"
  end

  def store_google_challenge!(challenge_token, payload)
    PASSWORD_REDIS.set(google_challenge_key(challenge_token), payload.to_json, ex: 5.minutes.to_i)
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Failed to store Google challenge: #{e.message}")
  end

  def fetch_google_challenge(challenge_token)
    raw_payload = PASSWORD_REDIS.get(google_challenge_key(challenge_token))
    return nil if raw_payload.blank?

    JSON.parse(raw_payload)
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Failed to fetch Google challenge: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[Auth] Invalid Google challenge payload: #{e.message}")
    nil
  end

  def clear_google_challenge!(challenge_token)
    PASSWORD_REDIS.del(google_challenge_key(challenge_token))
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Failed to clear Google challenge: #{e.message}")
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
