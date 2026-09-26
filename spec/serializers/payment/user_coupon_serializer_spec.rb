# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment::UserCouponSerializer do
  let(:coupon) { create(:payment_coupon, code: "SAVE50", title: "50% Off", coupon_type: "percentage") }
  let(:user_coupon) do
    create(
      :payment_user_coupon,
      coupon: coupon,
      discount_amount: 500,
      original_amount: 1000,
      final_amount: 500,
      currency: "usd"
    )
  end

  it "serializes user coupon attributes including coupon details" do
    serialized = described_class.record_attributes(user_coupon)

    expect(serialized).to include(
      id: user_coupon.id,
      code: "SAVE50",
      title: "50% Off",
      coupon_type: "percentage",
      coupon_code: "SAVE50",
      coupon_title: "50% Off",
      discount_amount: 500,
      original_amount: 1000,
      final_amount: 500,
      currency: "usd"
    )
  end

  it "returns nil when user_coupon is nil" do
    expect(described_class.record_attributes(nil)).to be_nil
  end
end
