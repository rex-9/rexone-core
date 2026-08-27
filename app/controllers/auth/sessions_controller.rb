# app/controllers/auth/sessions_controller.rb
class Auth::SessionsController < Devise::SessionsController
  include SessionPlatform

  LOG_PREFIX = "[Auth]".freeze

  respond_to :json

  skip_before_action :enforce_active_platform_session!, only: [ :create, :token_sign_in, :google_sign_in, :google_sign_in_complete ]

  # GET /peek?email=user@example.com
  def peek_user
    email = params[:email].to_s.strip.downcase

    if email.blank?
      render_json_response(
        status_code: 400,
        message: auth_message(MessageService::Auth::EMAIL_REQUIRED),
        error: auth_message(MessageService::Auth::EMAIL_MISSING)
      )
      return
    end

    user = User.with_discarded.find_by(email: email)

    return if reject_discarded_account!(user)

    render_json_response(
      status_code: 200,
      message: auth_message(MessageService::Auth::USER_EXISTENCE_CHECKED),
      data: {
        user_exists: user.present?,
        confirmed: user&.confirmed? || false
      }
    )
  end

  # POST /signin
  def create
    signin_key = params.dig(:user, :signin_key).to_s.strip
    password = params.dig(:user, :password)
    user = User.with_discarded.find_by(
      "email = :signin_key OR username = :signin_key",
      signin_key: signin_key
    )

    if user.nil?
      render_json_response(
        status_code: 401,
        message: auth_message(MessageService::Auth::SIGN_IN_FAILED),
        error: auth_message(MessageService::Auth::USER_NOT_FOUND)
      )
      return
    end

    return if reject_discarded_account!(user)

    limiter = PasswordService.new(user.id)
    unless limiter.allowed?
      render_json_response(
        status_code: 429,
        message: auth_message(MessageService::Auth::SIGN_IN_FAILED),
        error: auth_message(
          MessageService::Auth::TOO_MANY_ATTEMPTS_WITH_WAIT,
          seconds: limiter.cooldown_remaining
        ),
        data: {
          remaining_attempts: 0,
          cooldown_remaining: limiter.cooldown_remaining
        }
      )
      return
    end

    if user.valid_password?(password)
      limiter.record_success

      if user.confirmed?
        token = AppConfig::JWT_TOKEN.call(user)
        signup_active_session!(user: user, token: token)

        NotificationService::Center.sign_in_alert(
          user_id: user.id,
          name: user.name || user.username
        )

        render_json_response(
          status_code: 200,
          message: auth_message(MessageService::Auth::SIGNED_IN),
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: token
          }
        )
      else
        user.generate_confirmation_code
        user.send_confirmation_instructions

        NotificationService::Center.confirmation_email(
          email: user.email,
          code: user.confirmation_code
        )

        render_json_response(
          status_code: 200,
          message: auth_message(
            MessageService::Auth::CONFIRMATION_EMAIL_QUEUED,
            email: user.email
          ),
          data: { otp_sent: true }
        )
      end
    else
      failure_data = limiter.record_failure
      is_cooldown = (failure_data[:cooldown_remaining] || 0) > 0

      render_json_response(
        status_code: is_cooldown ? 429 : 401,
        message: auth_message(MessageService::Auth::SIGN_IN_FAILED),
        error: is_cooldown ?
          auth_message(MessageService::Auth::TOO_MANY_ATTEMPTS) :
          auth_message(MessageService::Auth::INVALID_CREDENTIALS),
        data: {
          remaining_attempts: failure_data[:remaining_attempts],
          cooldown_remaining: failure_data[:cooldown_remaining] || 0
        }
      )
    end
  end

  # POST /signin/token
  def token_sign_in
    user = User.with_discarded.find_by(jti: params[:token])
    if user
      return if reject_discarded_account!(user)

      sign_in(user)
      token = AppConfig::JWT_TOKEN.call(user)
      signup_active_session!(user: user, token: token)

      render_json_response(
        status_code: 200,
        message: auth_message(MessageService::Auth::SIGNED_IN),
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: token
        }
      )
    else
      render_json_response(
        status_code: 401,
        message: auth_message(MessageService::Auth::INVALID_TOKEN),
        error: auth_message(MessageService::Auth::INVALID_TOKEN)
      )
    end
  end

  # POST /signin/google
  def google_sign_in
    token = params[:token]
    user_info = GoogleAuthService.fetch_user_info(token)

    if !user_info || user_info["email"].blank?
      render_json_response(
        status_code: 401,
        message: auth_message(MessageService::Auth::GOOGLE_AUTH_FAILED),
        error: auth_message(MessageService::Auth::GOOGLE_AUTH_FAILED)
      )
      return
    end

    user = User.with_discarded.find_by(email: user_info["email"])

    if user
      return if reject_discarded_account!(user)

      if user.confirmed?
        token = AppConfig::JWT_TOKEN.call(user)
        signup_active_session!(user: user, token: token)
        NotificationService::Center.sign_in_alert(
          user_id: user.id,
          name: user.name || user.username
        )

        # Existing confirmed user - just return user + token
        render_json_response(
          status_code: 200,
          message: auth_message(MessageService::Auth::SIGNED_IN),
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: token
          }
        )
        return
      end
    end

    # New user or unconfirmed user - return challenge token
    challenge_token = SecureRandom.urlsafe_base64(32)

    challenge_payload = {
      email: user_info["email"],
      name: user_info["name"] || user&.name,
      picture: user_info["picture"]
    }

    store_google_challenge!(challenge_token, challenge_payload)

    render_json_response(
      status_code: 200,
      message: auth_message(MessageService::Auth::SET_PASSWORD),
      data: {
        password_required: true,
        challenge_token: challenge_token
      }
    )
  end

  # POST /signin/google/complete
  def google_sign_in_complete
    challenge_token = params[:challenge_token]
    password = params[:password].presence

    if challenge_token.blank? || password.blank?
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::SIGN_IN_FAILED),
        error: auth_message(MessageService::Auth::CHALLENGE_AND_PASSWORD_REQUIRED)
      )
      return
    end

    challenge_data = fetch_google_challenge(challenge_token)
    if challenge_data.blank?
      render_json_response(
        status_code: 401,
        message: auth_message(MessageService::Auth::INVALID_TOKEN),
        error: auth_message(MessageService::Auth::INVALID_TOKEN)
      )
      return
    end

    user = User.with_discarded.find_or_initialize_by(email: challenge_data["email"])
    return if reject_discarded_account!(user)

    if user.persisted?
      # User exists but was unconfirmed - update credentials, provider, and confirm
      user.assign_attributes(
        username: sanitized_username,
        name: challenge_data["name"],
        password: password,
        password_confirmation: password,
        provider: AuthConstants::Provider::GOOGLE,
        confirmed_at: user.confirmed_at || Time.current
      )

      if user.save
        if challenge_data["picture"].present?
          asset = user.assets.find_or_initialize_by(
            type: AssetConstants::AssetType::AVATAR,
            source: AssetConstants::AssetSource::GOOGLE
          )
          asset.assign_attributes(
            name: AssetConstants::AssetName.google_profile(user.id),
            url: challenge_data["picture"],
            format: AssetConstants::AssetFormat::IMAGE,
            resource: user
          )
          asset.save
        end

        clear_google_challenge!(challenge_token)

        token = AppConfig::JWT_TOKEN.call(user)
        signup_active_session!(user: user, token: token)

        NotificationService.welcome(
          user_id: user.id,
          name: user.name || user.username
        )

        render_json_response(
          status_code: 200,
          message: auth_message(MessageService::Auth::ACCOUNT_CREATED_AND_SIGNED_IN),
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: token
          }
        )
      else
        render_json_response(
          status_code: 422,
          message: auth_message(MessageService::Auth::GOOGLE_AUTH_FAILED),
          error: user.errors.full_messages.uniq.to_sentence
        )
      end
      return
    end

    # New user - create them
    sanitized_username = sanitize_email(challenge_data["email"])
    user.assign_attributes(
      username: sanitized_username,
      name: challenge_data["name"],
      password: password,
      password_confirmation: password,
      provider: AuthConstants::Provider::GOOGLE,
      confirmed_at: user.confirmed_at || Time.current
    )
   

    if user.save
      # Save google profile picture
      asset = Asset.new(
        name: AssetConstants::AssetName.google_profile(user.id),
        url: challenge_data["picture"],
        type: AssetConstants::AssetType::AVATAR,
        format: AssetConstants::AssetFormat::IMAGE,
        source: AssetConstants::AssetSource::GOOGLE,
        resource: user
      )

      unless asset.save
        Rails.logger.warn(
          "#{LOG_PREFIX} Failed to save Google profile picture " \
          "for user #{user.id}: #{asset.errors.full_messages}"
        )
        asset.assign_attributes(
          name: AssetConstants::AssetName.google_profile(user.id),
          url: challenge_data["picture"],
          format: AssetConstants::AssetFormat::IMAGE,
          resource: user
        )

        unless asset.save
          Rails.logger.warn(
            "#{LOG_PREFIX} Failed to save Google profile picture " \
            "for user #{user.id}: #{asset.errors.full_messages}"
          )
        end
      end

      clear_google_challenge!(challenge_token)

      token = AppConfig::JWT_TOKEN.call(user)
      signup_active_session!(user: user, token: token)

      NotificationService::Center.welcome(
        user_id: user.id,
        name: user.name || user.username
      )

      render_json_response(
        status_code: 201,
        message: auth_message(MessageService::Auth::ACCOUNT_CREATED_AND_SIGNED_IN),
        data: {
          user: UserSerializer.new(user).serializable_hash[:data][:attributes],
          token: token
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::GOOGLE_AUTH_FAILED),
        error: user.errors.full_messages.uniq.to_sentence
      )
    end
  end

  def respond_with(resource, _opts = {})
    return if resource.persisted? && reject_discarded_account!(resource)

    if resource.persisted?
      token = AppConfig::JWT_TOKEN.call(resource)
      signup_active_session!(user: resource, token: token)

      render_json_response(
        status_code: 200,
        message: auth_message(MessageService::Auth::SIGNED_IN),
        data: {
          user: UserSerializer.new(resource).serializable_hash[:data][:attributes],
          token: token
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: auth_message(MessageService::Auth::SIGN_IN_FAILED),
        error: resource.errors.full_messages.uniq.to_sentence
      )
    end
  end

  def destroy
    @user_before_sign_out = current_user
    super
  end

  # Devise normally checks whether the user is already signed out
  # before destroying the session. For this JWT API, logout is handled
  # explicitly by destroy/respond_to_on_destroy, so skip that check.
  def verify_signed_out_user(*_args); end

  def respond_to_on_destroy(*_args)
    if @user_before_sign_out
      clear_active_session!(@user_before_sign_out)

      render_json_response(
        status_code: 200,
        message: auth_message(MessageService::Auth::SIGNED_OUT)
      )
    else
      render_json_response(
        status_code: 401,
        message: auth_message(MessageService::Auth::SIGN_OUT_FAILED),
        error: auth_message(MessageService::Auth::ACTIVE_SESSION_NOT_FOUND)
      )
    end
  end

  private

  def auth_message(key, **options)
    MessageService::Auth.t(key, **options)
  end

  def reject_discarded_account!(user)
    return false unless user&.discarded?

    render_json_response(
      status_code: 403,
      message: auth_message(MessageService::Auth::ACCOUNT_DISCARDED),
      error: auth_message(MessageService::Auth::ACCOUNT_DISCARDED)
    )
    true
  end

  # Helper method to sanitize email addresses from Google sign-in
  def sanitize_email(email)
    local_part = email.split("@").first.downcase
    sanitized_username = local_part.gsub(/[^a-z0-9_]/, "_")
    if User.exists?(username: sanitized_username)
      "#{sanitized_username}_#{format('%06d', SecureRandom.random_number(10**6))}"
    else
      sanitized_username
    end
  end



  def session_key_for(user_id, platform = session_platform)
    "active_session:user:#{user_id}:#{platform}"
  end

  def signup_active_session!(user:, token:)
    CacheService.write(session_key_for(user.id), token, expires_in: AppConfig::SESSION_TIMEOUT)
  rescue => e
    Rails.logger.error("#{LOG_PREFIX} Failed to sign up active session: #{e.message}")
  end

  def clear_active_session!(user)
    token = request.headers[AuthConstants::Headers::AUTHORIZATION].to_s.split(" ").last
    key = session_key_for(user.id)
    active_token = CacheService.read(key)

    return if active_token.blank?

    if token.present? && active_token == token
      CacheService.delete(key)
    end
  rescue => e
    Rails.logger.error("#{LOG_PREFIX} Failed to clear active session: #{e.message}")
  end


  def google_challenge_key(challenge_token)
    "google_signin:challenge:#{challenge_token}"
  end

  def store_google_challenge!(challenge_token, payload)
    CacheService.write(google_challenge_key(challenge_token), payload.to_json, expires_in: 5.minutes)
  rescue => e
    Rails.logger.error("#{LOG_PREFIX} Failed to store Google challenge: #{e.message}")
  end

  def fetch_google_challenge(challenge_token)
    raw_payload = CacheService.read(google_challenge_key(challenge_token))
    return nil if raw_payload.blank?

    JSON.parse(raw_payload)
  rescue JSON::ParserError => e
    Rails.logger.error("#{LOG_PREFIX} Invalid Google challenge payload: #{e.message}")
    nil
  end

  def clear_google_challenge!(challenge_token)
    CacheService.delete(google_challenge_key(challenge_token))
  rescue => e
    Rails.logger.error("#{LOG_PREFIX} Failed to clear Google challenge: #{e.message}")
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
