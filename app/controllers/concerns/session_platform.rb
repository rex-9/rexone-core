# app/controllers/concerns/session_platform.rb
#
# Shared concern for resolving the client platform (web/mobile) from the
# request headers or params.  Included by both ApplicationController and the
# Devise-based auth controllers that do NOT inherit from ApplicationController.
module SessionPlatform
  extend ActiveSupport::Concern

  private

  def session_platform
    value = request.headers[AuthConstants::Headers::PLATFORM].presence ||
            params[:platform].presence ||
            AuthConstants::Platform::WEB
    AuthConstants::Platform::ALL.include?(value) ? value : AuthConstants::Platform::WEB
  end
end
