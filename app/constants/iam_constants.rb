# frozen_string_literal: true

# app/constants/iam_constants.rb
module IamConstants
  module Role
    SUPER_ADMIN = "super_admin".freeze
    ADMIN       = "admin".freeze
    USER        = "user".freeze
    ALL         = [ SUPER_ADMIN, ADMIN, USER ].freeze

    RESTRICTED_FOR_ADMIN = [
      "users",
      "iam_roles",
      "iam_permissions",
      "iam_user_roles",
      "client_versions",
      "client_user_versions"
    ].freeze
  end

  module Action
    READ   = "read".freeze
    CREATE = "create".freeze
    UPDATE = "update".freeze
    DELETE = "delete".freeze
    ALL    = [ READ, CREATE, UPDATE, DELETE ].freeze
  end

  module Resource
    # Top-level domain resources
    USERS                 = "users".freeze
    ACCESSES              = "accesses".freeze
    ASSETS                = "assets".freeze
    NOTIFICATIONS         = "notifications".freeze
    FEEDBACKS             = "feedbacks".freeze
    ANALYTICS             = "analytics".freeze
    SPEECH                = "speech".freeze

    # Module-namespaced resources
    AI_PROFILES           = "ai_profiles".freeze
    AI_RUNS               = "ai_runs".freeze
    CHAT_ROOMS            = "chat_rooms".freeze
    CHAT_MESSAGES         = "chat_messages".freeze
    CLIENT_LOGS           = "client_logs".freeze
    CLIENT_VERSIONS       = "client_versions".freeze
    CLIENT_USER_VERSIONS  = "client_user_versions".freeze
    IAM_ROLES             = "iam_roles".freeze
    IAM_PERMISSIONS       = "iam_permissions".freeze
    IAM_USER_ROLES        = "iam_user_roles".freeze
    PAYMENT_PRODUCTS      = "payment_products".freeze
    PAYMENT_PAYMENTS      = "payment_payments".freeze
    PAYMENT_SUBSCRIPTIONS = "payment_subscriptions".freeze
    PAYMENT_TRANSACTIONS  = "payment_transactions".freeze

    ALL = [
      USERS, ACCESSES, ASSETS, NOTIFICATIONS, FEEDBACKS, ANALYTICS, SPEECH,
      AI_PROFILES, AI_RUNS, CHAT_ROOMS, CHAT_MESSAGES,
      CLIENT_LOGS, CLIENT_VERSIONS, CLIENT_USER_VERSIONS,
      IAM_ROLES, IAM_PERMISSIONS, IAM_USER_ROLES,
      PAYMENT_PRODUCTS, PAYMENT_PAYMENTS, PAYMENT_SUBSCRIPTIONS, PAYMENT_TRANSACTIONS
    ].freeze

    # Compatibility aliases
    ROLES         = IAM_ROLES
    PERMISSIONS   = IAM_PERMISSIONS
    USER_ROLES    = IAM_USER_ROLES
    PRODUCTS      = PAYMENT_PRODUCTS
    PAYMENTS      = PAYMENT_PAYMENTS
    SUBSCRIPTIONS = PAYMENT_SUBSCRIPTIONS
    TRANSACTIONS  = PAYMENT_TRANSACTIONS
    LOGS          = CLIENT_LOGS
    VERSIONS      = CLIENT_VERSIONS
    USER_VERSIONS = CLIENT_USER_VERSIONS
  end

  module DefaultPermissions
    USER = [
      { resource: Resource::CLIENT_LOGS, actions: [ Action::CREATE ] },
      { resource: Resource::PAYMENT_PRODUCTS, actions: [ Action::READ ] },
      { resource: Resource::PAYMENT_PAYMENTS, actions: [ Action::CREATE ] },
      { resource: Resource::PAYMENT_SUBSCRIPTIONS, actions: [ Action::READ, Action::CREATE ] },
      { resource: Resource::PAYMENT_TRANSACTIONS, actions: [ Action::READ ] },
      { resource: Resource::ACCESSES, actions: [ Action::READ ] },
      { resource: Resource::ASSETS, actions: Action::ALL },
      { resource: Resource::USERS, actions: Action::ALL },
      { resource: Resource::CHAT_ROOMS, actions: Action::ALL },
      { resource: Resource::CHAT_MESSAGES, actions: Action::ALL },
      { resource: Resource::SPEECH, actions: Action::ALL },
      { resource: Resource::FEEDBACKS, actions: [ Action::CREATE, Action::READ ] },
      { resource: Resource::NOTIFICATIONS, actions: [ Action::READ, Action::UPDATE, Action::DELETE ] },
      { resource: Resource::CLIENT_VERSIONS, actions: [ Action::READ ] },
      { resource: Resource::CLIENT_USER_VERSIONS, actions: [ Action::CREATE ] }
    ].freeze
  end
end
