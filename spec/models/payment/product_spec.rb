require "rails_helper"

RSpec.describe Payment::Product, type: :model do
  it "validates Stripe identifiers, price, currency, and name" do
    expect(build(:payment_product)).to be_valid
    expect(build(:payment_product, name: nil)).not_to be_valid
    expect(build(:payment_product, price_unit_amount: -1)).not_to be_valid
    expect(build(:payment_product, stripe_product_id: nil)).not_to be_valid
  end

  it "treats zero-priced products as free" do
    product = build(
      :payment_product,
      price_unit_amount: 0
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
    monthly = build(:payment_product, cycle: "month", price_unit_amount: 1_250)
    one_time = build(:payment_product, cycle: nil)
    free = build(:payment_product, cycle: nil, price_unit_amount: 0)

    expect(monthly).to be_recurring
    expect(monthly.display_price).to eq("USD 12.50")
    expect(monthly.period_label).to eq("monthly")
    expect(monthly.cycle_in_duration).to eq(30.days)
    expect(one_time).not_to be_recurring
    expect(one_time.period_label).to eq("One-time purchase")
    expect(one_time.cycle_in_duration).to eq(0.days)
    expect(free.period_label).to eq("Lifetime")
  end

  it "separates active, one-time, and recurring products" do
    recurring = create(:payment_product)
    one_time = create(:payment_product, cycle: nil)
    create(:payment_product, active: false)
    expect(described_class.recurring).to include(recurring)
    expect(described_class.one_time).to contain_exactly(one_time)
    expect(described_class.active).to contain_exactly(recurring, one_time)
  end
end
