require "rails_helper"

RSpec.describe Ai::Profile, type: :model do
  it "validates key, provider, and numeric controls" do
    profile = build(:ai_profile, key: "invalid key!", provider: "unknown", temperature: 3, max_output_tokens: 0)

    expect(profile).not_to be_valid
    expect(profile.errors[:key]).to be_present
    expect(profile.errors[:provider]).to be_present
    expect(profile.errors[:temperature]).to be_present
    expect(profile.errors[:max_output_tokens]).to be_present
  end
end
