# app/jobs/payment/process_webhook_job.rb

class Payment::ProcessWebhookJob < ApplicationJob
  STRIPE_LOG_PREFIX = PaymentService::Stripe::STRIPE_LOG_PREFIX

  queue_as :payments

  # Never process the same persisted Stripe event concurrently.
  limits_concurrency(
    to: 1,
    key: ->(webhook_event_id) { webhook_event_id },
    duration: 15.minutes
  )

  # Temporary Stripe/network failures should be retried automatically.
  retry_on Stripe::APIConnectionError,
           Stripe::RateLimitError,
           Stripe::APIError,
           Net::OpenTimeout,
           Net::ReadTimeout,
           Timeout::Error,
           wait: :polynomially_longer,
           attempts: 10

  # Temporary database contention should also be retried.
  retry_on ActiveRecord::Deadlocked,
           ActiveRecord::ConnectionTimeoutError,
           wait: :polynomially_longer,
           attempts: 5

  def perform(webhook_event_id)
    webhook_event = Payment::WebhookEvent.find(webhook_event_id)

    # A retry or duplicate enqueue becomes a harmless no-op after the
    # event has already completed successfully.
    return if webhook_event.processed?

    webhook_event.with_lock do
      return if webhook_event.processed?

      webhook_event.start_processing!
    end

    PaymentService::Client.process_webhook(webhook_event.payload)

    webhook_event.mark_as_processed!

  rescue StandardError => error
    mark_webhook_as_failed(webhook_event, error)
    raise
  end

  private

  def mark_webhook_as_failed(webhook_event, error)
    return unless webhook_event.present?
    return if webhook_event.processed?

    webhook_event.mark_as_failed!(error)

  rescue StandardError => tracking_error
    Rails.logger.error(
      "#{STRIPE_LOG_PREFIX} Could not mark webhook #{webhook_event.id} as failed: " \
      "#{tracking_error.class}: #{tracking_error.message}"
    )
  end
end
