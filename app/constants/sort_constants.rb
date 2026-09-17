# frozen_string_literal: true

# app/constants/sort_constants.rb
module SortConstants
  module Order
    ASC = "asc".freeze
    DESC = "desc".freeze
    ALL = [ ASC, DESC ].freeze
  end

  module Columns
    USER        = %w[created_at name username email discarded_at].freeze
    ROLE        = %w[created_at name].freeze
    PRODUCT     = %w[created_at name unit_amount interval discarded_at].freeze
    TRANSACTION = %w[created_at paid_at unit_amount status currency].freeze
    SUBSCRIPTION = %w[created_at started_at current_period_end unit_amount status interval].freeze
    ACCESS      = %w[created_at user_name product_name expires_at revoked_at].freeze
    CHAT_ROOM   = %w[created_at title message_count discarded_at].freeze
    CHAT_MSG    = %w[created_at role discarded_at].freeze
    FEEDBACK    = %w[created_at user_name rating].freeze
    VERSION     = %w[created_at number title status released_at discarded_at install_count].freeze
    USER_VERSION = %w[last_seen_at number platform created_at].freeze
    CLIENT_LOG  = %w[created_at occurrence_count resolved_at].freeze
    NOTIF       = %w[created_at event].freeze
    USER_NOTIFICATION = %w[created_at read_at title discarded_at user_name user_email].freeze
    ASSET        = %w[created_at name title type format size_bytes duration_secs source discarded_at].freeze
    AI_PROFILE   = %w[created_at key name temperature provider model enabled discarded_at].freeze
    AI_RUN       = %w[created_at latency_ms total_tokens feature status model provider].freeze
    COUPON       = %w[created_at code title amount max_usage used_count expires_at discarded_at].freeze
    USER_COUPON  = %w[created_at discount_amount original_amount final_amount purchase_type user_email product_name coupon_code].freeze
  end
end
