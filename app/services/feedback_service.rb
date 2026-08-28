# app/services/feedback_service.rb

class FeedbackService
  LOG_PREFIX = "[Feedback]".freeze

  class << self
    def keywords_for(key)
      I18n.available_locales.flat_map do |locale|
        Array(I18n.t("feedback.triage.#{key}", locale: locale, default: []))
      end.uniq.compact
    end

    def bug_keywords
      keywords_for(:bug_keywords)
    end

    def feature_keywords
      keywords_for(:feature_keywords)
    end

    def improvement_keywords
      keywords_for(:improvement_keywords)
    end

    def urgent_keywords
      keywords_for(:urgent_keywords)
    end

    def infer_category(content)
      return FeedbackConstants::Category::GENERAL if content.blank?

      normalized = normalize_text(content)

      if bug_keywords.any? { |kw| match_keyword?(normalized, kw) }
        FeedbackConstants::Category::BUG
      elsif feature_keywords.any? { |kw| match_keyword?(normalized, kw) }
        FeedbackConstants::Category::FEATURE_REQUEST
      elsif improvement_keywords.any? { |kw| match_keyword?(normalized, kw) }
        FeedbackConstants::Category::IMPROVEMENT
      else
        FeedbackConstants::Category::GENERAL
      end
    end

    def infer_priority(content, rating)
      normalized = normalize_text(content)

      # Explicit urgency cues
      return FeedbackConstants::Priority::URGENT if urgent_keywords.any? { |kw| match_keyword?(normalized, kw) }

      # Critical sentiment cues: very low rating (1-2) with bug cues
      if rating.present? && rating <= 2 && bug_keywords.any? { |kw| match_keyword?(normalized, kw) }
        return FeedbackConstants::Priority::HIGH
      end

      if bug_keywords.any? { |kw| match_keyword?(normalized, kw) }
        FeedbackConstants::Priority::HIGH
      elsif improvement_keywords.any? { |kw| match_keyword?(normalized, kw) }
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

    private

    def normalize_text(content)
      content.to_s.downcase.gsub(/[\s-]+/, "_")
    end

    def match_keyword?(normalized_text, keyword)
      kw = keyword.to_s.downcase.gsub(/[\s-]+/, "_")
      normalized_text.include?(kw)
    end
  end
end
