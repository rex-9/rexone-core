# app/constants/feedback_constants.rb

module FeedbackConstants
  module Status
    NEW         = "new".freeze
    REVIEWED    = "reviewed".freeze
    IN_PROGRESS = "in_progress".freeze
    RESOLVED    = "resolved".freeze
    CLOSED      = "closed".freeze
    ALL         = [ NEW, REVIEWED, IN_PROGRESS, RESOLVED, CLOSED ].freeze
  end

  module Category
    BUG             = "bug".freeze
    FEATURE_REQUEST = "feature_request".freeze
    IMPROVEMENT     = "improvement".freeze
    GENERAL         = "general".freeze
    ALL             = [ BUG, FEATURE_REQUEST, IMPROVEMENT, GENERAL ].freeze
  end

  module Priority
    LOW      = "low".freeze
    MEDIUM   = "medium".freeze
    HIGH     = "high".freeze
    URGENT   = "urgent".freeze
    CRITICAL = "critical".freeze
    ALL      = [ LOW, MEDIUM, HIGH, URGENT, CRITICAL ].freeze
  end

  module Rating
    MIN = 1
    MAX = 10
  end
end
