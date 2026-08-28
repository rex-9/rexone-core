# app/controllers/concerns/session_platform.rb

# Shared concern for resolving the client platform (web/android/ios) from the
# X-Platform header or query parameter. Defaults to 'web' if missing or invalid.
module PlatformSession
  extend ActiveSupport::Concern

  private

  def session_platform
    value = request.headers[AuthConstants::Headers::PLATFORM].presence ||
            params[:platform].presence ||
            AuthConstants::Platform::WEB

    case value.to_s.downcase
    when AuthConstants::Platform::ANDROID then AuthConstants::Platform::ANDROID
    when AuthConstants::Platform::IOS     then AuthConstants::Platform::IOS
    when AuthConstants::Platform::WEB     then AuthConstants::Platform::WEB
    when "mobile"                         then AuthConstants::Platform::ANDROID
    else AuthConstants::Platform::WEB
    end
  end
end
