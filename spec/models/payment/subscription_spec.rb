require "rails_helper"

RSpec.describe Payment::Subscription, type: :model do
  it "validates identity and status" do
    expect(build(:payment_subscription)).to be_valid
    expect(build(:payment_subscription, stripe_subscription_id: nil)).not_to be_valid
    expect(build(:payment_subscription, status: nil)).not_to be_valid
  end

  it "reports cancellation, renewal, and expiry states" do
    subscription = build(:payment_subscription)
    expect(subscription).to be_active
    expect(subscription).to be_renewing
    expect(subscription).to be_cancelable

    subscription.cancel_at_period_end = true
    expect(subscription).to be_scheduled_for_cancellation
    expect(subscription).not_to be_renewing
    expect(subscription).not_to be_cancelable

    subscription.status = "canceled"
    expect(subscription).to be_ended
    expect(subscription).to be_expired
  end

  it "calculates renewal days without returning negative values" do
    travel_to(Time.zone.parse("2026-01-01 12:00:00")) do
      subscription = build(:payment_subscription, current_period_end: 2.2.days.from_now)
      expect(subscription.days_until_period_end).to eq(3)
      expect(subscription.days_until_renewal).to eq(3)

      subscription.current_period_end = 1.minute.ago
      expect(subscription.days_until_period_end).to eq(0)
    end
  end

  it "formats card details safely" do
    subscription = build(
      :payment_subscription,
      payment_method_id: "pm_1",
      payment_method_type: "card",
      payment_method_details: { "brand" => "visa", "last4" => "4242" }
    )
    expect(subscription.masked_card_number).to eq("**** **** **** 4242")
    expect(subscription.payment_method_display).to eq("Visa ending in 4242")
    expect(build(:payment_subscription).payment_method_display).to eq("Unknown")
  end
end
