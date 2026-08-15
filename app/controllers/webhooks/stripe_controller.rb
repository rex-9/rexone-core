# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ActionController::API
  def create
    payload = request.raw_post
    signature = request.headers["Stripe-Signature"]

    stripe_event = PaymentService::Client.verify_webhook(
      payload,
      signature
    )

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
      "[Stripe] Webhook queued: " \
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
      "[Stripe] Invalid webhook signature: #{error.message}"
    )
    render json: {
      received: false,
      error: "Invalid Stripe signature"
    }, status: :bad_request

  rescue JSON::ParserError => error
    Rails.logger.warn(
      "[Stripe] Invalid webhook payload: #{error.message}"
    )
    render json: {
      received: false,
      error: "Invalid JSON payload"
    }, status: :bad_request

  rescue SolidQueue::Job::EnqueueError => error
    Rails.error.report(error)
    Rails.logger.error(
      "[Stripe] Failed to enqueue webhook: #{error.message}"
    )
    # Returning a non-2xx response asks Stripe to retry delivery.
    render json: {
      received: false,
      error: "Webhook could not be queued"
    }, status: :service_unavailable

  rescue ActiveRecord::ActiveRecordError => error
    Rails.error.report(error)
    Rails.logger.error(
      "[Stripe] Failed to persist webhook: #{error.message}"
    )
    render json: {
      received: false,
      error: "Webhook could not be persisted"
    }, status: :internal_server_error

  rescue StandardError => error
    Rails.error.report(error)
    Rails.logger.error(
      "[Stripe] Unexpected webhook error: " \
      "#{error.class}: #{error.message}"
    )
    render json: {
      received: false,
      error: "Webhook processing failed"
    }, status: :internal_server_error
  end

  private

  def persist_webhook_event!(stripe_event, raw_payload)
    Payment::WebhookEvent.create_or_find_by!(
      stripe_event_id: stripe_event.id
    ) do |webhook_event|
      webhook_event.event_type = stripe_event.type
      webhook_event.livemode = stripe_event.livemode || false
      webhook_event.payload = JSON.parse(raw_payload)
      webhook_event.received_at = Time.current
    end
  end
end
