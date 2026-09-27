require "rails_helper"

RSpec.describe Payment::Purchase, type: :model do
  it "validates its Stripe identifier and amount" do
    expect(build(:payment_purchase)).to be_valid
    expect(build(:payment_purchase, stripe_payment_intent_id: nil)).not_to be_valid
    expect(build(:payment_purchase, unit_amount: 0)).not_to be_valid
  end

  it "exposes success, pending, and failure states" do
    purchase = build(:payment_purchase, status: "succeeded")
    expect(purchase).to be_paid
    purchase.status = "processing"
    expect(purchase).to be_pending
    purchase.status = "canceled"
    expect(purchase).to be_failed
  end

  it "syncs mutable fields from a Stripe payment intent" do
    purchase = create(:payment_purchase, status: "processing")
    intent = OpenStruct.new(
      status: "succeeded", amount: 1_000, currency: "usd",
      amount_received: 1_000, amount_capturable: 0,
      client_secret: "secret", metadata: { "order" => "1" }
    )
    purchase.sync_with_payment_intent(intent)
    expect(purchase.reload).to have_attributes(
      status: "succeeded", unit_amount: 1_000, currency: "usd",
      amount_received: 1_000, client_secret: "secret"
    )
    expect(purchase.paid_at).to be_present
  end

  it "marks lifecycle timestamps" do
    purchase = create(:payment_purchase, status: "requires_payment_method")
    purchase.mark_as_processing!
    expect(purchase.processing_at).to be_present
    purchase.mark_as_succeeded!
    expect(purchase.paid_at).to be_present
    purchase.mark_as_canceled!
    expect(purchase.canceled_at).to be_present
  end
end
