require "rails_helper"

RSpec.describe EmailService::Templates do
  it "keeps provider template identifiers in the email boundary" do
    expect(described_class::ALL.values).to contain_exactly(
      "email_confirmation",
      "password_reset",
      "payment_purchase_confirmation",
      "payment_subscription_confirmation",
      "payment_subscription_canceled",
      "payment_subscription_resumed",
      "payment_failed",
      "general_announcement",
      "maintenance_notice",
      "feature_update"
    )
  end
end
