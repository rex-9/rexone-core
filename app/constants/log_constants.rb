# app/constants/log_constants.rb

module LogConstants
  module Severity
    DEBUG    = "debug".freeze
    INFO     = "info".freeze
    WARNING  = "warning".freeze
    ERROR    = "error".freeze
    CRITICAL = "critical".freeze
    ALL      = [ DEBUG, INFO, WARNING, ERROR, CRITICAL ].freeze
  end

  module Platform
    WEB     = "web".freeze
    IOS     = "ios".freeze
    ANDROID = "android".freeze
    ALL     = [ WEB, IOS, ANDROID ].freeze
  end

  module Environment
    DEVELOPMENT = "development".freeze
    STAGING     = "staging".freeze
    PRODUCTION  = "production".freeze
    ALL         = [ DEVELOPMENT, STAGING, PRODUCTION ].freeze
  end
end
