# frozen_string_literal: true
# app/constants/ai_constants/chat_status.rb

module AiConstants
  module ChatStatus
    QUEUED     = "queued".freeze
    PROCESSING = "processing".freeze
    RETRYING   = "retrying".freeze
    COMPLETED  = "completed".freeze
    FAILED     = "failed".freeze

    ALL = [ QUEUED, PROCESSING, RETRYING, COMPLETED, FAILED ].freeze
    PROCESSING_SET = [ QUEUED, PROCESSING, RETRYING ].freeze
  end
end
