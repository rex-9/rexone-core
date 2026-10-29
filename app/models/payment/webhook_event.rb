# app/models/payment/webhook_event.rb

class Payment::WebhookEvent < ApplicationRecord
  STRIPE_LOG_PREFIX = Payment::Providers::Stripe::STRIPE_LOG_PREFIX

  self.table_name = "payment_webhook_events"

  # PROCESSED_RETENTION_PERIOD = 30.seconds
  PROCESSED_RETENTION_PERIOD = 30.days
  CLEANUP_BATCH_SIZE = 1_000
  FAILED_RETENTION_PERIOD = 180.days

  # ===== ENUMS =====
  enum :status, {
    pending: PaymentConstants::WebhookStatus::PENDING,
    processing: PaymentConstants::WebhookStatus::PROCESSING,
    processed: PaymentConstants::WebhookStatus::PROCESSED,
    failed: PaymentConstants::WebhookStatus::FAILED
  }

  # ===== VALIDATIONS =====
  validates :provider, presence: true, inclusion: { in: PaymentConstants::Provider::ALL }
  validates :provider_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, presence: true
  validates :payload, presence: true
  validates :received_at, presence: true
  validate :validate_payload

  validates :attempt_count,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  # ===== SCOPES =====
  scope :recent, -> { order(received_at: :desc) }
  scope :retryable, -> { where(status: [ PaymentConstants::WebhookStatus::PENDING, PaymentConstants::WebhookStatus::FAILED ]) }

  scope :processed_before, ->(time) {
    where(status: PaymentConstants::WebhookStatus::PROCESSED).where("processed_at < ?", time)
  }
  scope :failed_before, ->(time) {
    where(status: PaymentConstants::WebhookStatus::FAILED).where("updated_at < ?", time)
  }

  # ===== INSTANCE METHODS =====
  def start_processing!
    update!(
      status: PaymentConstants::WebhookStatus::PROCESSING,
      processing_started_at: Time.current,
      attempt_count: attempt_count + 1,
      last_error: nil
    )
  end

  def mark_as_processed!
    update!(
      status: PaymentConstants::WebhookStatus::PROCESSED,
      processed_at: Time.current,
      last_error: nil
    )
  end

  def mark_as_failed!(error)
    update!(
      status: PaymentConstants::WebhookStatus::FAILED,
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

  private

  def validate_payload
    errors.add(:payload, "must be a valid key-value object") unless payload.is_a?(Hash)
  end
end
