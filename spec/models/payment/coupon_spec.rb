require "rails_helper"

RSpec.describe Payment::Coupon, type: :model do
  let(:product) { create(:payment_product, unit_amount: 10_000, currency: "usd") }
  let(:user) { create(:user) }

  it "validates presence of title, code, amount, and coupon_type" do
    expect(build(:payment_coupon)).to be_valid
    expect(build(:payment_coupon, title: nil)).not_to be_valid
    expect(build(:payment_coupon, code: nil)).not_to be_valid
    expect(build(:payment_coupon, amount: 0)).not_to be_valid
  end

  it "normalizes coupon code to uppercase" do
    coupon = create(:payment_coupon, code: "save20now")
    expect(coupon.code).to eq("SAVE20NOW")
  end

  it "enforces code validation rules (alphanumeric only, min 6 chars, no hyphens or special chars)" do
    expect(build(:payment_coupon, code: "ABCDE")).not_to be_valid
    expect(build(:payment_coupon, code: "SAVE-20")).not_to be_valid
    expect(build(:payment_coupon, code: "SAVE_20")).not_to be_valid
    expect(build(:payment_coupon, code: "SAVE!20")).not_to be_valid
    expect(build(:payment_coupon, code: "SAVE 20")).not_to be_valid
    expect(build(:payment_coupon, code: "PROMO2026")).to be_valid
  end

  it "enforces unique codes case-insensitively" do
    create(:payment_coupon, code: "DISCOUNT")
    expect(build(:payment_coupon, code: "discount")).not_to be_valid
  end

  it "validates max_usage_per_user cannot exceed max_usage" do
    coupon = build(:payment_coupon, max_usage: 5, max_usage_per_user: 10)
    expect(coupon).not_to be_valid
    expect(coupon.errors[:max_usage_per_user]).to be_present
  end

  it "calculates percentage discount accurately" do
    coupon = build(:payment_coupon, coupon_type: :percentage, amount: 25)
    result = coupon.calculate_discount(product)

    expect(result[:discount_amount]).to eq(2_500)
    expect(result[:final_amount]).to eq(7_500)
  end

  it "calculates fixed discount accurately and caps at product price" do
    coupon = build(:payment_coupon, coupon_type: :fixed, amount: 3_000, currency: "usd")
    result = coupon.calculate_discount(product)

    expect(result[:discount_amount]).to eq(3_000)
    expect(result[:final_amount]).to eq(7_000)

    over_discount = build(:payment_coupon, coupon_type: :fixed, amount: 15_000, currency: "usd")
    capped_result = over_discount.calculate_discount(product)
    expect(capped_result[:discount_amount]).to eq(10_000)
    expect(capped_result[:final_amount]).to eq(0)
  end

  it "validates product targeting restrictions" do
    allowed_product = create(:payment_product)
    forbidden_product = create(:payment_product)

    coupon = create(:payment_coupon, target_product_ids: [ allowed_product.id ])

    expect(coupon.applicable_to?(user: user, product: allowed_product)).to be(true)
    expect(coupon.applicable_to?(user: user, product: forbidden_product)).to be(false)
  end

  it "validates user targeting restrictions" do
    allowed_user = create(:user)
    forbidden_user = create(:user)

    coupon = create(:payment_coupon, target_user_ids: [ allowed_user.id ])

    expect(coupon.applicable_to?(user: allowed_user, product: product)).to be(true)
    expect(coupon.applicable_to?(user: forbidden_user, product: product)).to be(false)
  end

  it "validates role targeting restrictions" do
    role = create(:role, name: "vip_role")
    create(:user_role, user: user, role: role)
    other_user = create(:user)

    coupon = create(:payment_coupon, target_role_ids: [ role.id ])

    expect(coupon.applicable_to?(user: user, product: product)).to be(true)
    expect(coupon.applicable_to?(user: other_user, product: product)).to be(false)
  end

  it "rejects expired coupons" do
    expired_coupon = create(:payment_coupon, expires_at: 1.day.ago)
    expect(expired_coupon.applicable_to?(user: user, product: product)).to be(false)
  end

  it "rejects coupons that reached max usage" do
    exhausted_coupon = create(:payment_coupon, max_usage: 5, used_count: 5)
    expect(exhausted_coupon.applicable_to?(user: user, product: product)).to be(false)
  end

  it "enforces per-user usage limits" do
    coupon = create(:payment_coupon, max_usage_per_user: 1)
    expect(coupon.applicable_to?(user: user, product: product)).to be(true)

    create(:payment_user_coupon, coupon: coupon, user: user, product: product)
    expect(coupon.applicable_to?(user: user, product: product)).to be(false)
  end

  it "allows currency-agnostic percentage coupons when currency is nil" do
    coupon = create(:payment_coupon, coupon_type: :percentage, amount: 15, currency: nil)
    mmk_product = create(:payment_product, currency: "mmk", unit_amount: 50_000)

    expect(coupon.applicable_to?(user: user, product: product)).to be(true)
    expect(coupon.applicable_to?(user: user, product: mmk_product)).to be(true)
  end

  it "rejects currency mismatch when currency is specified" do
    coupon = create(:payment_coupon, coupon_type: :fixed, amount: 500, currency: "usd")
    sgd_product = create(:payment_product, currency: "sgd", unit_amount: 10_000)

    expect(coupon.applicable_to?(user: user, product: sgd_product)).to be(false)
  end

  it "enforces immutability of financial terms on update" do
    coupon = create(:payment_coupon, title: "Original Title", amount: 20, coupon_type: :percentage)

    # Allowed updates
    expect(coupon.update(title: "Updated Title", active: false, metadata: { "tier" => "gold" })).to be(true)
    expect(coupon.reload.title).to eq("Updated Title")
    expect(coupon.metadata).to eq({ "tier" => "gold" })

    # Prohibited financial updates
    expect(coupon.update(amount: 30)).to be(false)
    expect(coupon.errors[:base]).to include(match(/immutable/i))

    expect(coupon.update(code: "NEWCODE2026")).to be(false)
    expect(coupon.errors[:base]).to include(match(/immutable/i))

    expect(coupon.update(coupon_type: :fixed)).to be(false)
    expect(coupon.errors[:base]).to include(match(/immutable/i))
  end

  it "prohibits setting active: true on failed status coupons" do
    coupon = create(:payment_coupon, active: false, metadata: { "status" => "failed", "sync_error" => "Card error" })

    expect(coupon.sync_failed?).to be(true)
    expect(coupon.sync_processing?).to be(false)

    # Attempting to activate failed coupon must fail
    expect(coupon.update(active: true)).to be(false)
    expect(coupon.errors[:active]).to include(match(/cannot be set to true for coupons that failed Stripe/i))

    # Updating other non-financial fields while inactive is allowed
    coupon.reload
    expect(coupon.update(title: "Updated Pending Title")).to be(true)

    # Hard delete is allowed
    expect { coupon.destroy! }.not_to raise_error
  end

  it "cleans up Stripe coupon when destroyed" do
    coupon = create(:payment_coupon, stripe_coupon_id: "STRIPE_CLEANUP_123")
    allow(Stripe::Coupon).to receive(:delete)

    coupon.destroy!

    expect(Stripe::Coupon).to have_received(:delete).with("STRIPE_CLEANUP_123")
  end

  it "correctly identifies sync statuses" do
    proc_coupon = build(:payment_coupon, metadata: { "status" => "processing" })
    expect(proc_coupon.sync_processing?).to be(true)
    expect(proc_coupon.sync_succeeded?).to be(false)
    expect(proc_coupon.sync_failed?).to be(false)

    succ_coupon = build(:payment_coupon, metadata: { "status" => "succeeded" })
    expect(succ_coupon.sync_succeeded?).to be(true)
    expect(succ_coupon.sync_processing?).to be(false)

    fail_coupon = build(:payment_coupon, metadata: { "status" => "failed" })
    expect(fail_coupon.sync_failed?).to be(true)
    expect(fail_coupon.sync_succeeded?).to be(false)
  end
end
