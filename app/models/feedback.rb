# app/models/feedback.rb

class Feedback < ApplicationRecord
  self.primary_key = "id"

  belongs_to :user, optional: true

  # ===== ENUMS =====
  enum :status, FeedbackConstants::Status::ALL.index_with(&:itself), prefix: true
  enum :category, FeedbackConstants::Category::ALL.index_with(&:itself), prefix: true
  enum :priority, FeedbackConstants::Priority::ALL.index_with(&:itself), prefix: true
  enum :platform, AuthConstants::Platform::ALL.index_with(&:itself), prefix: true

  # ===== VALIDATIONS =====
  validates :content, presence: true, length: { minimum: 1, maximum: 5000 }
  validates :rating, numericality: {
    only_integer: true,
    greater_than_or_equal_to: FeedbackConstants::Rating::MIN,
    less_than_or_equal_to: FeedbackConstants::Rating::MAX
  }, allow_nil: true
  validates :category, inclusion: { in: FeedbackConstants::Category::ALL }
  validates :priority, inclusion: { in: FeedbackConstants::Priority::ALL }
  validates :status, inclusion: { in: FeedbackConstants::Status::ALL }
  validates :platform, inclusion: { in: AuthConstants::Platform::ALL }

  # ===== SCOPES =====
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_priority, ->(priority) { where(priority: priority) if priority.present? }
  scope :by_platform, ->(platform) { where(platform: platform) if platform.present? }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
end
