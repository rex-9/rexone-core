# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment::SyncBatchCouponsJob, type: :job do
  describe "#perform" do
    it "synchronizes batch coupons, activates them, and updates metadata to succeeded" do
      coupon1 = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })
      coupon2 = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })

      allow(CouponService).to receive(:ensure_stripe_coupon).with(coupon1, raise_on_error: true) do
        coupon1.update_column(:stripe_coupon_id, coupon1.code)
        coupon1.code
      end
      allow(CouponService).to receive(:ensure_stripe_coupon).with(coupon2, raise_on_error: true) do
        coupon2.update_column(:stripe_coupon_id, coupon2.code)
        coupon2.code
      end

      described_class.perform_now([coupon1.id, coupon2.id])

      coupon1.reload
      coupon2.reload

      expect(coupon1.active).to be(true)
      expect(coupon1.metadata["status"]).to eq(PaymentConstants::SyncStatus::SUCCEEDED)
      expect(coupon1.metadata["synced_at"]).to be_present

      expect(coupon2.active).to be(true)
      expect(coupon2.metadata["status"]).to eq(PaymentConstants::SyncStatus::SUCCEEDED)
      expect(coupon2.metadata["synced_at"]).to be_present
    end

    it "marks coupon as failed and leaves active: false on non-retryable error" do
      failed_coupon = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })
      success_coupon = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })

      allow(CouponService).to receive(:ensure_stripe_coupon).with(failed_coupon, raise_on_error: true).and_raise(StandardError, "Stripe coupon creation failed")
      allow(CouponService).to receive(:ensure_stripe_coupon).with(success_coupon, raise_on_error: true) do
        success_coupon.update_column(:stripe_coupon_id, success_coupon.code)
        success_coupon.code
      end

      described_class.perform_now([failed_coupon.id, success_coupon.id])

      failed_coupon.reload
      success_coupon.reload

      expect(failed_coupon.active).to be(false)
      expect(failed_coupon.metadata["status"]).to eq(PaymentConstants::SyncStatus::FAILED)
      expect(failed_coupon.metadata["sync_error"]).to eq("Stripe coupon creation failed")
      expect(failed_coupon.metadata["failed_at"]).to be_present

      expect(success_coupon.active).to be(true)
      expect(success_coupon.metadata["status"]).to eq(PaymentConstants::SyncStatus::SUCCEEDED)
    end

    it "skips coupons that have already succeeded or already failed" do
      synced_coupon = create(:payment_coupon, active: true, stripe_coupon_id: "SYNCED123", metadata: { "status" => "succeeded" })
      failed_coupon = create(:payment_coupon, active: false, metadata: { "status" => "failed" })

      expect(CouponService).not_to receive(:ensure_stripe_coupon)

      described_class.perform_now([synced_coupon.id, failed_coupon.id])
    end

    it "retries on Stripe rate limit or connection errors" do
      coupon = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })

      allow(CouponService).to receive(:ensure_stripe_coupon).with(coupon, raise_on_error: true).and_raise(Stripe::RateLimitError.new("Rate limit exceeded"))

      expect_any_instance_of(described_class).to receive(:retry_job)
      described_class.perform_now([coupon.id])
    end

    it "marks coupon as failed when retries are exhausted" do
      coupon = create(:payment_coupon, active: false, stripe_coupon_id: nil, metadata: { "status" => "processing" })

      job = described_class.new([coupon.id])
      error = Stripe::RateLimitError.new("Rate limit exceeded")
      job.handle_retry_exhaustion(error)

      coupon.reload
      expect(coupon.active).to be(false)
      expect(coupon.metadata["status"]).to eq(PaymentConstants::SyncStatus::FAILED)
      expect(coupon.metadata["sync_error"]).to include("Exhausted retries: Rate limit exceeded")
      expect(coupon.metadata["failed_at"]).to be_present
    end
  end
end
