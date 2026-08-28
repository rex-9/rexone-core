# app/services/feedback_service.rb

class FeedbackService
  LOG_PREFIX = "[Feedback]".freeze

  # Heuristic keyword matching for smart intent detection without user decision fatigue
  BUG_KEYWORDS = %w[
    bug error crash broken fail failing exception freeze frozen stuck glitch
    not_working doesn't_work cannot can't 500 404 timeout blank
  ].freeze

  FEATURE_KEYWORDS = %w[
    feature suggest suggestion request please_add wish would_love idea
    could_you_add integration
  ].freeze

  IMPROVEMENT_KEYWORDS = %w[
    improve improvement slow faster optimize design ux ui layout confusing
    hard_to enhance better
  ].freeze

  URGENT_KEYWORDS = %w[
    urgent critical blocker emergency immediately security hack leak
    lost_money charged_twice cannot_login cannot_access
  ].freeze

  class << self
    def infer_category(content)
      return FeedbackConstants::Category::GENERAL if content.blank?

      normalized = content.to_s.downcase.gsub(/[\s-]+/, "_")

      if BUG_KEYWORDS.any? { |kw| normalized.include?(kw) }
        FeedbackConstants::Category::BUG
      elsif FEATURE_KEYWORDS.any? { |kw| normalized.include?(kw) }
        FeedbackConstants::Category::FEATURE_REQUEST
      elsif IMPROVEMENT_KEYWORDS.any? { |kw| normalized.include?(kw) }
        FeedbackConstants::Category::IMPROVEMENT
      else
        FeedbackConstants::Category::GENERAL
      end
    end

    def infer_priority(content, rating)
      normalized = content.to_s.downcase.gsub(/[\s-]+/, "_")

      # Explicit urgency cues
      return FeedbackConstants::Priority::URGENT if URGENT_KEYWORDS.any? { |kw| normalized.include?(kw) }

      # Critical sentiment cues: very low rating (1-2) with bug cues
      if rating.present? && rating <= 2 && BUG_KEYWORDS.any? { |kw| normalized.include?(kw) }
        return FeedbackConstants::Priority::HIGH
      end

      if BUG_KEYWORDS.any? { |kw| normalized.include?(kw) }
        FeedbackConstants::Priority::HIGH
      elsif IMPROVEMENT_KEYWORDS.any? { |kw| normalized.include?(kw) }
        FeedbackConstants::Priority::NORMAL
      else
        FeedbackConstants::Priority::LOW
      end
    end

    def create(params, user: nil, platform: "web")
      content = params[:content].to_s.strip
      rating = params[:rating].presence&.to_i

      category = params[:category].presence || infer_category(content)
      priority = params[:priority].presence || infer_priority(content, rating)

      feedback = Feedback.new(
        user: user,
        content: content,
        rating: rating,
        category: category,
        priority: priority,
        status: FeedbackConstants::Status::NEW,
        platform: platform,
        app_version: params[:app_version],
        os: params[:os],
        device: params[:device],
        browser: params[:browser],
        page: params[:page] || params[:screen_name],
        metadata: params[:metadata] || {}
      )

      feedback.save!
      feedback
    end
  end
end
