# app/models/user_notification.rb
class UserNotification < ApplicationRecord
  self.table_name = "user_notifications"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :notification, optional: true

  # ===== VALIDATIONS =====
  validates :title, presence: true
  validates :message, presence: true

  # ===== SCOPES =====
  scope :unread, -> { where(read_at: nil) }
  scope :read_scope, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # ===== CALLBACKS =====
  after_create_commit :increment_notification_sent_count, if: -> { notification_id.present? }
  after_update_commit :increment_notification_read_count, if: -> { saved_change_to_read_at? && read_at_before_last_save.nil? && read_at.present? && notification_id.present? }

  # ===== METHODS =====
  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  private

  def increment_notification_sent_count
    Notification.unscoped.where(id: notification_id).update_all("sent_count = COALESCE(sent_count, 0) + 1")
  end

  def increment_notification_read_count
    Notification.unscoped.where(id: notification_id).update_all("read_count = COALESCE(read_count, 0) + 1")
  end
end
