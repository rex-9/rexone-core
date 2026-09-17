require "rails_helper"

RSpec.describe CouponService, type: :service do
  let(:user) { create(:user) }
  let(:product) { create(:payment_product, unit_amount: 10_000, currency: "usd") }

  describe ".validate" do
    it "returns valid for an active, available coupon" do
      coupon = create(:payment_coupon, code: "PROMO20", amount: 20, coupon_type: :percentage)

      result = described_class.validate(user: user, product: product, code: "promo20")

      expect(result[:valid]).to be(true)
      expect(result[:discount_amount]).to eq(2_000)
      expect(result[:final_amount]).to eq(8_000)
    end

    it "returns invalid error when coupon is not found" do
      result = described_class.validate(user: user, product: product, code: "NONEXISTENT")

      expect(result[:valid]).to be(false)
      expect(result[:error]).to eq(MessageService::Payment::COUPON_INVALID)
    end

    it "returns invalid error when coupon is expired or exhausted" do
      expired = create(:payment_coupon, code: "EXPIRED", expires_at: 1.day.ago)
      result = described_class.validate(user: user, product: product, code: "EXPIRED")

      expect(result[:valid]).to be(false)
      expect(result[:error]).to eq(MessageService::Payment::COUPON_INVALID)
    end
  end

  describe "rate limiting" do
    let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(CacheService).to receive(:read) { |k| cache_store.read(k) }
      allow(CacheService).to receive(:write) { |k, v, opts| cache_store.write(k, v, opts) }
      allow(CacheService).to receive(:delete) { |k| cache_store.delete(k) }
      allow(CacheService).to receive(:increment) do |k, amount, opts|
        val = (cache_store.read(k) || 0) + amount
        cache_store.write(k, val, opts)
        val
      end
    end

    it "allows attempts when no cooldown is active" do
      expect(described_class.allowed?(user.id)).to be(true)
      expect(described_class.cooldown_remaining(user.id)).to eq(0)
    end

    it "progresses through cooldown ladder on consecutive failures" do
      # Attempt 1
      res1 = described_class.record_failure(user.id)
      expect(res1[:remaining_attempts]).to eq(2)
      expect(res1[:cooldown_remaining]).to eq(0)
      expect(res1[:locked]).to be(false)

      # Attempt 2
      res2 = described_class.record_failure(user.id)
      expect(res2[:remaining_attempts]).to eq(1)
      expect(res2[:cooldown_remaining]).to eq(0)

      # Attempt 3 -> 30s cooldown
      res3 = described_class.record_failure(user.id)
      expect(res3[:remaining_attempts]).to eq(0)
      expect(res3[:cooldown_remaining]).to eq(30)
      expect(res3[:locked]).to be(true)
      expect(described_class.allowed?(user.id)).to be(false)
      expect(described_class.cooldown_remaining(user.id)).to be > 0
    end

    it "resets attempts and cooldown on record_success" do
      described_class.record_failure(user.id)
      described_class.record_failure(user.id)
      described_class.record_failure(user.id)

      expect(described_class.allowed?(user.id)).to be(false)

      described_class.record_success(user.id)
      expect(described_class.allowed?(user.id)).to be(true)
      expect(described_class.cooldown_remaining(user.id)).to eq(0)
    end
  end

  describe ".apply_to_checkout!" do
    it "increments used_count and creates a user_coupon record" do
      coupon = create(:payment_coupon, max_usage: 10, used_count: 0)
      trx = create(:payment_transaction, user: user, product: product)

      expect {
        described_class.apply_to_checkout!(
          user: user,
          product: product,
          coupon: coupon,
          purchase_id: trx.id,
          purchase_type: :trx
        )
      }.to change { Payment::UserCoupon.count }.by(1)

      expect(coupon.reload.used_count).to eq(1)
      user_coupon = Payment::UserCoupon.last
      expect(user_coupon.coupon_id).to eq(coupon.id)
      expect(user_coupon.user_id).to eq(user.id)
      expect(user_coupon.purchase_id).to eq(trx.id)
      expect(user_coupon).to be_trx
    end

    it "raises an error if max usage has already been reached" do
      coupon = create(:payment_coupon, max_usage: 1, used_count: 1)
      trx = create(:payment_transaction, user: user, product: product)

      expect {
        described_class.apply_to_checkout!(
          user: user,
          product: product,
          coupon: coupon,
          purchase_id: trx.id,
          purchase_type: :trx
        )
      }.to raise_error(PaymentService::Error)
    end
  end
end
