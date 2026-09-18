require "rails_helper"

RSpec.describe Payment::UserCoupon, type: :model do
  it "validates required attributes" do
    expect(build(:payment_user_coupon)).to be_valid
    expect(build(:payment_user_coupon, purchase_id: nil)).not_to be_valid
    expect(build(:payment_user_coupon, discount_amount: -1)).not_to be_valid
  end

  it "resolves the underlying purchase entity" do
    trx = create(:payment_transaction)
    user_coupon = create(:payment_user_coupon, purchase_id: trx.id, purchase_type: :trx)

    expect(user_coupon).to be_trx
    expect(user_coupon.purchase).to eq(trx)
  end
end
