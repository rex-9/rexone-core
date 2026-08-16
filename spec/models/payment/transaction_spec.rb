require "rails_helper"

RSpec.describe Payment::Transaction, type: :model do
  it "validates its Stripe identifier and amount" do
    expect(build(:payment_transaction)).to be_valid
    expect(build(:payment_transaction, stripe_payment_intent_id: nil)).not_to be_valid
    expect(build(:payment_transaction, price_unit_amount: 0)).not_to be_valid
  end

  it "exposes success, pending, and failure states" do
    transaction = build(:payment_transaction, status: "succeeded")
    expect(transaction).to be_paid
    transaction.status = "processing"
    expect(transaction).to be_pending
    transaction.status = "canceled"
    expect(transaction).to be_failed
  end

  it "syncs mutable fields from a Stripe payment intent" do
    transaction = create(:payment_transaction, status: "processing")
    intent = OpenStruct.new(
      status: "succeeded", amount_received: 1_000, amount_capturable: 0,
      client_secret: "secret", metadata: { "order" => "1" }
    )
    transaction.sync_with_payment_intent(intent)
    expect(transaction.reload).to have_attributes(status: "succeeded", amount_received: 1_000, client_secret: "secret")
    expect(transaction.paid_at).to be_present
  end

  it "marks lifecycle timestamps" do
    transaction = create(:payment_transaction, status: "requires_payment_method")
    transaction.mark_as_processing!
    expect(transaction.processing_at).to be_present
    transaction.mark_as_succeeded!
    expect(transaction.paid_at).to be_present
    transaction.mark_as_canceled!
    expect(transaction.canceled_at).to be_present
  end
end
