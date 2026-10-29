# frozen_string_literal: true

# app/constants/ai_constants.rb
module AiConstants
  module AiPrompt
    DEFAULT_ANALYSIS = "sentiment".freeze
  end

  module Provider
    DEEPSEEK  = "deepseek".freeze
    GEMINI    = "gemini".freeze
    OPENAI    = "openai".freeze
    ANTHROPIC = "anthropic".freeze

    ALL = [ DEEPSEEK, GEMINI, OPENAI, ANTHROPIC ].freeze
  end

  module Pricing
    DEFAULT_CURRENCY = "usd".freeze
    DECIMAL_PRECISION = 6
    PER_MILLION = 1_000_000
    DEFAULT_CACHE_DISCOUNT_RATIO = 0.5
    PRICING_REGISTRY_URL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json".freeze
    SYNC_OPEN_TIMEOUT = 5
    SYNC_READ_TIMEOUT = 10

    module RegistryKeys
      PROVIDER = "litellm_provider".freeze
      INPUT_COST = "input_cost_per_token".freeze
      CACHED_INPUT_COST = "cache_read_input_token_cost".freeze
      OUTPUT_COST = "output_cost_per_token".freeze
    end
  end

  module UsageKeys
    USAGE                      = "usage".freeze
    PROMPT_TOKENS              = "prompt_tokens".freeze
    COMPLETION_TOKENS          = "completion_tokens".freeze
    TOTAL_TOKENS               = "total_tokens".freeze
    CACHED_TOKENS              = "cached_tokens".freeze
    PROMPT_TOKENS_DETAILS      = "prompt_tokens_details".freeze
    CACHE_READ_INPUT_TOKENS    = "cache_read_input_tokens".freeze
    USAGE_METADATA             = "usage_metadata".freeze
    CACHED_CONTENT_TOKEN_COUNT = "cached_content_token_count".freeze
  end

  module ResponseKeys
    CHOICES       = "choices".freeze
    MESSAGE       = "message".freeze
    CONTENT       = "content".freeze
    FINISH_REASON = "finish_reason".freeze
    LENGTH        = "length".freeze
    ROLE          = "role".freeze
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


  module RunStatus
    PROCESSING = "processing".freeze
    COMPLETED  = "completed".freeze
    FAILED     = "failed".freeze

    ALL = [ PROCESSING, COMPLETED, FAILED ].freeze
  end


  module Defaults
    TEMPERATURE          = 0.7
    MAX_OUTPUT_TOKENS    = 10000
    CONTEXT_MAX_TOKENS   = 8000
    HISTORY_MAX_MESSAGES = 20
    TIMEOUT_SECONDS      = 60
    MESSAGE_MAX_CHARS    = 2000
  end
end
