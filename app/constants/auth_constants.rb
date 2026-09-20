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

  module Provider
    EMAIL  = "email".freeze
    GOOGLE = "google".freeze
  end
end
