# app/constants/access_constants/access_status.rb

module AccessConstants
  module AccessStatus
    ACTIVE  = "active".freeze
    EXPIRED = "expired".freeze
    REVOKED = "revoked".freeze
    ALL     = [ ACTIVE, EXPIRED, REVOKED ].freeze
  end
end
