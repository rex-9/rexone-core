class ApplicationController < ActionController::API
  include Authorization
  include ApplicationHelper

  # Skip authorization for certain actions
  # skip_before_action :authorize_action!, only: [ :render_json_response, :sanitize_email ]

  before_action :enforce_active_platform_session!

  private

  def enforce_active_platform_session!
    return unless current_user

    bearer_token = request.headers["Authorization"].to_s.split(" ").last
    return if bearer_token.blank?

    key = "active_session:user:#{current_user.id}:#{session_platform}"
    active_token = PASSWORD_REDIS.get(key)
    return if active_token.present? && active_token == bearer_token

    render_json_response(
      status_code: 401,
      message: Messages::FAILED_TO_SIGN_IN,
      error: Messages::ACTIVE_SESSION_NOT_FOUND
    )
  rescue Redis::BaseError => e
    Rails.logger.error("[Auth] Active session verification failed: #{e.message}")
  end

  def session_platform
    value = request.headers["X-Platform"].presence || params[:platform].presence || "web"
    %w[web mobile].include?(value) ? value : "web"
  end
end
