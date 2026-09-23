# frozen_string_literal: true

# app/jobs/payment/sync_batch_coupons_job.rb

module Payment
  class SyncBatchCouponsJob < ApplicationJob
    queue_as :payments

    RETRYABLE_EXCEPTIONS = [
      Stripe::APIConnectionError,
      Stripe::RateLimitError,
      Stripe::APIError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Timeout::Error
    ].freeze

    # Temporary Stripe/network failures are retried automatically.
    retry_on(*RETRYABLE_EXCEPTIONS,
             wait: :polynomially_longer,
             attempts: 5) do |job, error|
      job.handle_retry_exhaustion(error)
    end

    def perform(coupon_ids)
      return if coupon_ids.blank?

      coupons = ::Payment::Coupon.where(id: coupon_ids)
      coupons.find_each do |coupon|
        next if coupon.sync_succeeded? && coupon.stripe_coupon_id.present?
        next if coupon.sync_failed?

        sync_coupon(coupon)
      end
    end

    def handle_retry_exhaustion(error)
      coupon_ids = arguments.first
      return if coupon_ids.blank?

      ::Payment::Coupon.where(id: coupon_ids, active: false).find_each do |coupon|
        next if coupon.sync_succeeded?

        new_metadata = (coupon.metadata || {}).merge(
          "status" => PaymentConstants::SyncStatus::FAILED,
          "sync_error" => "Exhausted retries: #{error.message}",
          "failed_at" => Time.current.iso8601
        )
        coupon.update_columns(active: false, metadata: new_metadata)
      end
    end

    private

    def sync_coupon(coupon)
      stripe_id = CouponService.ensure_stripe_coupon(coupon, raise_on_error: true)
      if stripe_id.present?
        new_metadata = (coupon.metadata || {}).merge(
          "status" => PaymentConstants::SyncStatus::SUCCEEDED,
          "synced_at" => Time.current.iso8601
        ).except("sync_error", "failed_at")

        coupon.update_columns(
          active: true,
          metadata: new_metadata
        )
      else
        mark_as_failed(coupon, "Stripe coupon creation returned empty ID")
      end
    rescue Stripe::APIConnectionError, Stripe::RateLimitError, Stripe::APIError, Timeout::Error => e
      # Re-raise transient network/rate-limit error so ActiveJob handles retries with polynomial backoff
      raise e
    rescue StandardError => e
      # Unrecoverable error: mark as failed and inactive without re-raising
      mark_as_failed(coupon, e.message)
    end

    def mark_as_failed(coupon, error_message)
      new_metadata = (coupon.metadata || {}).merge(
        "status" => PaymentConstants::SyncStatus::FAILED,
        "sync_error" => error_message,
        "failed_at" => Time.current.iso8601
      )
      coupon.update_columns(
        active: false,
        metadata: new_metadata
      )
      Rails.logger.error("[SyncBatchCouponsJob] Failed to sync coupon #{coupon.code}: #{error_message}")
    end
  end
end
