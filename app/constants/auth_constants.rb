# frozen_string_literal: true

# app/constants/auth_constants.rb
module AuthConstants
  module ClientRoutes
    PASSWORD_RESET = "/password/reset".freeze
  end

  module Headers
    PLATFORM         = "X-Platform".freeze
    LOCALE           = "X-Locale".freeze
    ACCEPT_LANGUAGE  = "Accept-Language".freeze
    AUTHORIZATION    = "Authorization".freeze
    FORWARDED_HOST   = "X-Forwarded-Host".freeze
    FORWARDED_FOR    = "X-Forwarded-For".freeze
    FORWARDED_PROTO  = "X-Forwarded-Proto".freeze
    STRIPE_SIGNATURE = "Stripe-Signature".freeze
    CONTENT_TYPE     = "Content-Type".freeze
    HOST             = "Host".freeze
  end

  module Platform
    WEB     = "web".freeze
    ANDROID = "android".freeze
    IOS     = "ios".freeze
    ALL     = [ WEB, ANDROID, IOS ].freeze
  end

  module Session
    PREFIX = "active_session:user".freeze

    def self.key(user_id, platform)
      "#{PREFIX}:#{user_id}:#{platform}"
    end

    def self.clear_all(user_id)
      Platform::ALL.each do |platform|
        CacheService.delete(key(user_id, platform))
      end
    end
  end

  module Provider
    EMAIL  = "email".freeze
    GOOGLE = "google".freeze
  end

  module Google
    TIMEOUT       = 10
    TOKENINFO_URL = "https://www.googleapis.com/oauth2/v3/tokeninfo".freeze
    USERINFO_URL  = "https://www.googleapis.com/oauth2/v1/userinfo".freeze
  end
end
