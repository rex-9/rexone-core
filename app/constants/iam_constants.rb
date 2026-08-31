# app/constants/iam_constants.rb

module IamConstants
  module Role
    SUPER_ADMIN = "super_admin".freeze
    ADMIN       = "admin".freeze
    USER        = "user".freeze
    ALL         = [ SUPER_ADMIN, ADMIN, USER ].freeze
  end

  module Action
    READ   = "read".freeze
    CREATE = "create".freeze
    UPDATE = "update".freeze
    DELETE = "delete".freeze
    ALL    = [ READ, CREATE, UPDATE, DELETE ].freeze
  end

  module Resource
    USERS         = "users".freeze
    ROLES         = "roles".freeze
    USER_ROLES    = "user_roles".freeze
    PERMISSIONS   = "permissions".freeze
    PRODUCTS      = "products".freeze
    PAYMENTS      = "payments".freeze
    SUBSCRIPTIONS = "subscriptions".freeze
    TRANSACTIONS  = "transactions".freeze
    ACCESS        = "access".freeze
    ASSETS        = "assets".freeze
    NOTIFICATIONS = "notifications".freeze
    AI            = "ai".freeze
    SPEECH        = "speech".freeze
    CLIENTS       = "clients".freeze
    FEEDBACKS     = "feedbacks".freeze
    ALL           = [
      USERS, ROLES, USER_ROLES, PERMISSIONS, PRODUCTS, PAYMENTS,
      SUBSCRIPTIONS, TRANSACTIONS, ACCESS, ASSETS, NOTIFICATIONS,
      AI, SPEECH, CLIENTS, FEEDBACKS
    ].freeze
  end
end
