require "rails_helper"

RSpec.describe Access, type: :model do
  it "requires a grant timestamp" do
    expect(build(:access)).to be_valid
    expect(build(:access, granted_at: nil)).not_to be_valid
  end

  it "accounts for status and real expiration time" do
    access = build(:access, expires_at: 1.hour.from_now)
    expect(access).to be_active
    expect(access).not_to be_expired

    access.expires_at = 1.second.ago
    expect(access).not_to be_active
    expect(access).to be_expired
  end

  it "records revocation and expiration" do
    access = create(:access)
    access.revoke!
    expect(access).to have_attributes(status: "revoked")
    expect(access.revoked_at).to be_present

    access.expire!
    expect(access).to have_attributes(status: "expired")
    expect(access.expired_at).to be_present
  end

  it "formats finite and permanent access" do
    travel_to(Time.zone.parse("2026-01-01 12:00:00")) do
      access = build(:access, expires_at: 2.1.days.from_now)
      expect(access.remaining_days).to eq(3)
      expect(access.display_expiry).to eq("Jan 03, 2026")
      access.expires_at = nil
      expect(access.remaining_days).to be_nil
      expect(access.display_expiry).to eq("Never")
    end
  end
end
