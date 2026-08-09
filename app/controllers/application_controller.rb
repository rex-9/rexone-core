# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Authorization
  include ApplicationHelper

  before_action :enforce_active_platform_session!

  private

  def enforce_active_platform_session!
    return unless current_user

    bearer_token = request.headers["Authorization"].to_s.split(" ").last
    return if bearer_token.blank?

    key = session_key(current_user.id)
    active_token = CacheService.read(key)

    if active_token.blank? || active_token != bearer_token
      render_json_response(
        status_code: 401,
        message: Messages::FAILED_TO_SIGN_IN,
        error: Messages::ACTIVE_SESSION_NOT_FOUND
      )
      return
    end

    # Refresh the session TTL on each request
    CacheService.write(key, bearer_token, expires_in: AppConfig::SESSION_TIMEOUT)
  rescue => e
    Rails.logger.error("[Auth] Active session verification failed: #{e.message}")
  end

  def session_platform
    value = request.headers["X-Platform"].presence || params[:platform].presence || "web"
    %w[web mobile].include?(value) ? value : "web"
  end

  def session_key(user_id)
    "active_session:user:#{user_id}:#{session_platform}"
  end
end
