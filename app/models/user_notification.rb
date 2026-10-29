# app/models/user_notification.rb
class UserNotification < ApplicationRecord
  self.table_name = "user_notifications"

  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :notification, optional: true

  has_metadata UserNotification::Metadata

  # ===== VALIDATIONS =====
  validates :title, presence: true
  validates :message, presence: true
  validates :operation_id, uniqueness: { scope: :user_id }, allow_nil: true
  validates :operation_type, inclusion: { in: NotificationConstants::OperationType::ALL }, allow_nil: true
  validates :operation_status, inclusion: { in: NotificationConstants::OperationStatus::ALL }, allow_nil: true
  validate :clients_are_valid
  validate :complete_operation_metadata

  # ===== SCOPES =====
  scope :unread, -> { where(read_at: nil) }
  scope :read_scope, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_client, ->(client) { where("clients @> ARRAY[?]::varchar[]", client.to_s) }

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

  def clients_are_valid
    valid = clients.is_a?(Array) && clients.present? && clients.uniq == clients &&
      clients.all? { |client| client.match?(NotificationConstants::Client::FORMAT) }
    return if valid

    errors.add(:clients, :invalid)
  end

  def complete_operation_metadata
    fields = [ operation_id, operation_type, operation_status ]
    return if fields.all?(&:blank?) || fields.all?(&:present?)

    errors.add(:operation_id, "operation metadata must be supplied together")
  end

  def increment_notification_sent_count
    Notification.unscoped.where(id: notification_id).update_all("sent_count = COALESCE(sent_count, 0) + 1")
  end

  def increment_notification_read_count
    Notification.unscoped.where(id: notification_id).update_all("read_count = COALESCE(read_count, 0) + 1")
  end
end
