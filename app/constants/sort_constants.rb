# frozen_string_literal: true

module SortConstants
  module Order
    ASC = "asc".freeze
    DESC = "desc".freeze
    ALL = [ ASC, DESC ].freeze
  end

  module Columns
    USER        = %w[created_at name username email discarded_at].freeze
    ROLE        = %w[created_at name].freeze
    PRODUCT     = %w[created_at name price_unit_amount cycle discarded_at].freeze
    ACCESS      = %w[created_at user_name product_name expires_at revoked_at].freeze
    CHAT_ROOM   = %w[created_at title message_count discarded_at].freeze
    CHAT_MSG    = %w[created_at role discarded_at].freeze
    FEEDBACK    = %w[created_at user_name rating].freeze
    CLIENT_LOG  = %w[created_at occurrence_count resolved_at].freeze
    NOTIF       = %w[created_at event].freeze
  end
end
