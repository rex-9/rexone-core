# app/models/payment/webhook_event.rb

class Payment::WebhookEvent < ApplicationRecord
  STRIPE_LOG_PREFIX = PaymentService::Stripe::STRIPE_LOG_PREFIX

  self.table_name = "payment_webhook_events"

  # PROCESSED_RETENTION_PERIOD = 30.seconds
  PROCESSED_RETENTION_PERIOD = 30.days
  CLEANUP_BATCH_SIZE = 1_000
  FAILED_RETENTION_PERIOD = 180.days

  # ===== ENUMS =====
  enum :status, {
    pending: "pending",
    processing: "processing",
    processed: "processed",
    failed: "failed"
  }

  # ===== VALIDATIONS =====
  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, presence: true
  validates :payload, presence: true
  validates :received_at, presence: true

  validates :attempt_count,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  # ===== SCOPES =====
  scope :recent, -> { order(received_at: :desc) }
  scope :retryable, -> { where(status: %w[pending failed]) }

  scope :processed_before, ->(time) {
    where(status: "processed").where("processed_at < ?", time)
  }
  scope :failed_before, ->(time) {
    where(status: "failed").where("updated_at < ?", time)
  }

  # ===== INSTANCE METHODS =====
  def start_processing!
    update!(
      status: "processing",
      processing_started_at: Time.current,
      attempt_count: attempt_count + 1,
      last_error: nil
    )
  end

  def mark_as_processed!
    update!(
      status: "processed",
      processed_at: Time.current,
      last_error: nil
    )
  end

  def mark_as_failed!(error)
    update!(
      status: "failed",
      last_error: error.message
    )
  end

  def self.cleanup_old!
    processed_count =
      processed_before(PROCESSED_RETENTION_PERIOD.ago)
        .in_batches(of: CLEANUP_BATCH_SIZE)
        .delete_all

    failed_count =
      failed_before(FAILED_RETENTION_PERIOD.ago)
        .in_batches(of: CLEANUP_BATCH_SIZE)
        .delete_all

    Rails.logger.info(
      "#{STRIPE_LOG_PREFIX} Webhook cleanup completed: " \
      "processed_deleted=#{processed_count} " \
      "failed_deleted=#{failed_count} "
    )

    {
      processed_deleted: processed_count,
      failed_deleted: failed_count
    }
  end
end
