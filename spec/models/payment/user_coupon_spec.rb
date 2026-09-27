require "rails_helper"

RSpec.describe Payment::UserCoupon, type: :model do
  it "validates required attributes" do
    expect(build(:payment_user_coupon)).to be_valid
    expect(build(:payment_user_coupon, payment_id: nil)).not_to be_valid
    expect(build(:payment_user_coupon, discount_amount: -1)).not_to be_valid
  end

  it "resolves the underlying payment entity" do
    purchase = create(:payment_purchase)
    user_coupon = create(:payment_user_coupon, payment_id: purchase.id, payment_type: :purchase)

    expect(user_coupon).to be_purchase
    expect(user_coupon.payment).to eq(purchase)
  end
end
