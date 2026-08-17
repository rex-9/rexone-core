require "rails_helper"

RSpec.describe AccessService do
  let(:user) { create(:user) }
  let(:product) { create(:payment_product) }

  it "grants recurring access using the product cycle" do
    travel_to(Time.zone.parse("2026-01-01 12:00:00")) do
      access = described_class.grant(user_id: user.id, product_id: product.id)
      expect(access).to have_attributes(status: "active", expires_at: 30.days.from_now)
    end
  end

  it "grants one-time access without expiration" do
    product.update!(cycle: nil)
    expect(described_class.grant(user_id: user.id, product_id: product.id).expires_at).to be_nil
  end

  it "reactivates existing access while preserving its original grant time" do
    original = create(:access, user: user, product: product, status: "revoked", granted_at: 1.year.ago, revoked_at: Time.current)
    renewed = described_class.grant(user_id: user.id, product_id: product.id, expires_at: 10.days.from_now)
    expect(renewed.granted_at).to be_within(1.second).of(original.granted_at)
    expect(renewed).to have_attributes(status: "active", revoked_at: nil, expired_at: nil)
  end

  it "revokes active access and ignores missing or already inactive access" do
    access = create(:access, user: user, product: product)
    described_class.revoke(user_id: user.id, product_id: product.id)
    expect(access.reload).to be_revoked
    expect { described_class.revoke(user_id: SecureRandom.uuid, product_id: product.id) }.not_to raise_error
  end

  it "checks and returns only currently valid access" do
    valid = create(:access, user: user, product: product)
    expired = create(:access, expires_at: 1.minute.ago)
    expect(described_class.has_access?(user_id: user.id, product_id: product.id)).to be(true)
    expect(described_class.has_access?(user_id: expired.user_id, product_id: expired.product_id)).to be(false)
    expect(described_class.get_active_access(user.id)).to contain_exactly(valid)
  end
end
