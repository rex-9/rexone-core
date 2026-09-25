require "rails_helper"

RSpec.describe Payment::Product, type: :model do
  it "becomes inactive when discarded" do
    product = create(:payment_product, active: true)

    product.discard!

    expect(product.reload).to be_discarded
    expect(product.active).to be(false)
  end

  it "validates Stripe identifiers, price, currency, and name" do
    expect(build(:payment_product)).to be_valid
    expect(build(:payment_product, name: nil)).not_to be_valid
    expect(build(:payment_product, unit_amount: -1)).not_to be_valid
    expect(build(:payment_product, stripe_product_id: nil)).not_to be_valid
  end

  it "treats zero-priced products as free" do
    product = build(
      :payment_product,
      unit_amount: 0
    )

    expect(product).to be_valid
    expect(product).to be_free
    expect(product).not_to be_premium
    expect(product.display_price).to eq("Free")
  end

  it "enforces unique Stripe product and price identifiers" do
    product = create(:payment_product)
    expect(build(:payment_product, stripe_product_id: product.stripe_product_id)).not_to be_valid
    expect(build(:payment_product, stripe_price_id: product.stripe_price_id)).not_to be_valid
  end

  it "describes recurring and one-time pricing" do
    monthly = build(:payment_product, interval: "month", unit_amount: 1_250)
    one_time = build(:payment_product, interval: nil)
    free = build(:payment_product, interval: nil, unit_amount: 0)

    expect(monthly).to be_recurring
    expect(monthly.display_price).to eq("USD 12.50")
    expect(monthly.period_label).to eq("monthly")
    expect(monthly.interval_in_duration).to eq(30.days)
    expect(one_time).not_to be_recurring
    expect(one_time.period_label).to eq("One-time purchase")
    expect(one_time.interval_in_duration).to eq(0.days)
    expect(free.period_label).to eq("One-time purchase")
  end

  it "separates active, one-time, and recurring products" do
    recurring = create(:payment_product)
    one_time = create(:payment_product, interval: nil)
    create(:payment_product, active: false)
    expect(described_class.recurring).to include(recurring)
    expect(described_class.one_time).to contain_exactly(one_time)
    expect(described_class.active).to contain_exactly(recurring, one_time)
  end

  it "prevents converting a free product to a premium product" do
    free_product = create(:payment_product, unit_amount: 0)

    free_product.unit_amount = 2500
    expect(free_product).not_to be_valid
    expect(free_product.errors[:unit_amount]).to include("Free products cannot be converted to premium products")
  end

  it "prevents converting a premium product to a free product" do
    premium_product = create(:payment_product, unit_amount: 2500)

    premium_product.unit_amount = 0
    expect(premium_product).not_to be_valid
    expect(premium_product.errors[:unit_amount]).to include("Premium products cannot be converted to free products")
  end

  describe "code generation and validation" do
    it "auto-generates a 10-character alphanumeric code on create" do
      product = create(:payment_product, code: nil)
      expect(product.code).to be_present
      expect(product.code.length).to eq(10)
      expect(product.code).to match(/\A[A-Za-z0-9]{10}\z/)
    end

    it "preserves a custom valid 10-character alphanumeric code" do
      custom_code = "Abc123XyZ9"
      product = create(:payment_product, code: custom_code)
      expect(product.code).to eq(custom_code)
    end

    it "validates that code is 10 alphanumeric characters" do
      expect(build(:payment_product, code: "short")).not_to be_valid
      expect(build(:payment_product, code: "too_long_code_123")).not_to be_valid
      expect(build(:payment_product, code: "abc123-xyz")).not_to be_valid
    end

    it "enforces case-sensitive uniqueness of code" do
      create(:payment_product, code: "Abc123XyZ9")
      duplicate = build(:payment_product, code: "Abc123XyZ9")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:code, :taken)).to be(true)
    end

    it "prevents updating code on an existing product" do
      product = create(:payment_product, code: "Initial123")
      expect {
        product.code = "Updated456"
      }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe "Stripe minimum amount validation" do
    it "allows free products with unit_amount of 0" do
      product = build(:payment_product, unit_amount: 0, interval: nil)
      expect(product).to be_valid
    end

    it "allows premium products meeting or exceeding the Stripe minimum amount" do
      product = build(:payment_product, unit_amount: 50, currency: "usd")
      expect(product).to be_valid

      sgd_product = build(:payment_product, unit_amount: 50, currency: "sgd")
      expect(sgd_product).to be_valid
    end

    it "rejects premium products below the Stripe minimum amount" do
      product = build(:payment_product, unit_amount: 49, currency: "usd")
      expect(product).not_to be_valid
      expect(product.errors[:unit_amount]).to include("must be at least 50 for USD to satisfy Stripe minimum charge limits")
    end

    it "enforces minimum limits on product updates" do
      product = create(:payment_product, unit_amount: 1_000, currency: "usd")
      product.unit_amount = 25
      expect(product).not_to be_valid
      expect(product.errors[:unit_amount]).to include("must be at least 50 for USD to satisfy Stripe minimum charge limits")
    end
  end
end
