# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ActionController::API
  STRIPE_LOG_PREFIX = PaymentService::Stripe::STRIPE_LOG_PREFIX

  def create
    payload = request.raw_post
    signature = request.headers["Stripe-Signature"]

    stripe_event = PaymentService::Client.verify_webhook(
      payload,
      signature
    )

    unless PaymentService::Client.supported_webhook_event?(
      stripe_event.type
    )
      Rails.logger.info(
        "#{STRIPE_LOG_PREFIX} Ignored unsupported webhook event: " \
        "#{stripe_event.type}"
      )

      render json: {
        received: true,
        event_id: stripe_event.id,
        status: "ignored"
      }, status: :ok

      return
    end

    webhook_event = persist_webhook_event!(
      stripe_event,
      payload
    )
    if webhook_event.processed?
      render json: {
        received: true,
        event_id: webhook_event.stripe_event_id,
        status: "already_processed"
      }, status: :ok

      return
    end

    job = Payment::ProcessWebhookJob.perform_later(
      webhook_event.id
    )

    Rails.logger.info(
      "#{STRIPE_LOG_PREFIX} Webhook queued: " \
      "event_id=#{webhook_event.stripe_event_id} " \
      "event_type=#{webhook_event.event_type} " \
      "job_id=#{job.job_id}"
    )

    render json: {
      received: true,
      event_id: webhook_event.stripe_event_id,
      status: "queued",
      job_id: job.job_id
    }, status: :ok

  rescue Stripe::SignatureVerificationError => error
    Rails.logger.warn(
      "#{STRIPE_LOG_PREFIX} Invalid webhook signature: #{error.message}"
    )
    render json: {
      received: false,
      error: payment_message(MessageService::Payment::INVALID_STRIPE_SIGNATURE)
    }, status: :bad_request

  rescue JSON::ParserError => error
    Rails.logger.warn(
      "#{STRIPE_LOG_PREFIX} Invalid webhook payload: #{error.message}"
    )
    render json: {
      received: false,
      error: payment_message(MessageService::Payment::INVALID_JSON_PAYLOAD)
    }, status: :bad_request

  rescue SolidQueue::Job::EnqueueError => error
    Rails.error.report(error)
    Rails.logger.error(
      "#{STRIPE_LOG_PREFIX} Failed to enqueue webhook: #{error.message}"
    )
    # Returning a non-2xx response asks Stripe to retry delivery.
    render json: {
      received: false,
      error: payment_message(MessageService::Payment::WEBHOOK_QUEUE_FAILED)
    }, status: :service_unavailable

  rescue ActiveRecord::ActiveRecordError => error
    Rails.error.report(error)
    Rails.logger.error(
      "#{STRIPE_LOG_PREFIX} Failed to persist webhook: #{error.message}"
    )
    render json: {
      received: false,
      error: payment_message(MessageService::Payment::WEBHOOK_PERSIST_FAILED)
    }, status: :internal_server_error

  rescue StandardError => error
    Rails.error.report(error)
    Rails.logger.error(
      "#{STRIPE_LOG_PREFIX} Unexpected webhook error: " \
      "#{error.class}: #{error.message}"
    )
    render json: {
      received: false,
      error: payment_message(MessageService::Payment::WEBHOOK_PROCESSING_FAILED)
    }, status: :internal_server_error
  end

  private

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

  def persist_webhook_event!(stripe_event, raw_payload)
    Payment::WebhookEvent.find_or_create_by!(
      stripe_event_id: stripe_event.id
    ) do |webhook_event|
      webhook_event.event_type = stripe_event.type
      webhook_event.livemode = stripe_event.livemode || false
      webhook_event.payload = JSON.parse(raw_payload)
      webhook_event.received_at = Time.current
    end
  rescue ActiveRecord::RecordNotUnique
    Payment::WebhookEvent.find_by!(stripe_event_id: stripe_event.id)
  end
end
