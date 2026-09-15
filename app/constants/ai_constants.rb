# frozen_string_literal: true

# app/constants/ai_constants.rb
module AiConstants
  module AiPrompt
    DEFAULT_ANALYSIS = "sentiment".freeze
  end

  module Provider
    DEEPSEEK = "deepseek".freeze
    GEMINI   = "gemini".freeze

    ALL = [ DEEPSEEK, GEMINI ].freeze
  end

  module ProfileKey
    CHAT_DEFAULT = "chat_default".freeze
    SUMMARIZE    = "summarize".freeze
    TRANSLATE    = "translate".freeze
    ANALYZE      = "analyze".freeze

    ALL = [ CHAT_DEFAULT, SUMMARIZE, TRANSLATE, ANALYZE ].freeze
  end

  module AnalysisType
    SENTIMENT = "sentiment".freeze
    ENTITIES  = "entities".freeze
    KEYWORDS  = "keywords".freeze

    ALL = [ SENTIMENT, ENTITIES, KEYWORDS ].freeze
  end

  module ChatRole
    SYSTEM    = "system".freeze
    USER      = "user".freeze
    ASSISTANT = "assistant".freeze
  end

  module ChatStatus
    QUEUED     = "queued".freeze
    PROCESSING = "processing".freeze
    RETRYING   = "retrying".freeze
    COMPLETED  = "completed".freeze
    FAILED     = "failed".freeze

    ALL = [ QUEUED, PROCESSING, RETRYING, COMPLETED, FAILED ].freeze
    PROCESSING_SET = [ QUEUED, PROCESSING, RETRYING ].freeze
  end

  module RunFeature
    CHAT      = "chat".freeze
    SUMMARIZE = "summarize".freeze
    TRANSLATE = "translate".freeze
    ANALYZE   = "analyze".freeze

    ALL = [ CHAT, SUMMARIZE, TRANSLATE, ANALYZE ].freeze
  end

  module RequestMetadata
    ENDPOINT      = "endpoint".freeze
    ROOM_ID       = "room_id".freeze
    LANGUAGE      = "language".freeze
    ANALYSIS_TYPE = "analysis_type".freeze
  end

  module RunStatus
    PROCESSING = "processing".freeze
    COMPLETED  = "completed".freeze
    FAILED     = "failed".freeze

    ALL = [ PROCESSING, COMPLETED, FAILED ].freeze
  end

  module ChunkMetadata
    CHUNK_INDEX  = "chunk_index".freeze
    TOTAL_CHUNKS = "total_chunks".freeze
    SPLIT_ID     = "split_id".freeze
  end

  module Defaults
    TEMPERATURE          = 0.7
    MAX_OUTPUT_TOKENS    = 4000
    CONTEXT_MAX_TOKENS   = 8000
    HISTORY_MAX_MESSAGES = 20
    TIMEOUT_SECONDS      = 60
    MESSAGE_MAX_CHARS    = 2000
  end
end
