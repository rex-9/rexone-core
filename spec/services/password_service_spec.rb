require "rails_helper"

RSpec.describe PasswordService do
  subject(:service) { described_class.new(user_id) }

  let(:user_id) { SecureRandom.uuid }

  before do
    allow(CacheService).to receive(:read).and_return(nil)
    allow(CacheService).to receive(:write)
    allow(CacheService).to receive(:delete)
  end

  it "allows attempts when no cooldown is active" do
    expect(service).to be_allowed
    expect(service.cooldown_remaining).to eq(0)
  end

  it "reports an active cooldown" do
    allow(CacheService).to receive(:read).and_return(Time.now.to_i + 20)
    expect(service).not_to be_allowed
    expect(service.cooldown_remaining).to be_between(19, 20)
  end

  it "uses escalating cooldowns at three, six, nine, and twelve failures" do
    { 3 => 30, 6 => 60, 9 => 120, 12 => 300 }.each do |attempts, cooldown|
      allow(CacheService).to receive(:increment).and_return(attempts)
      expect(service.record_failure).to include(
        remaining_attempts: 0,
        cooldown_remaining: cooldown,
        locked: true
      )
    end
  end

  it "reports remaining attempts before a cooldown" do
    allow(CacheService).to receive(:increment).and_return(1)
    expect(service.record_failure).to include(remaining_attempts: 2, cooldown_remaining: 0, locked: false)
  end

  it "clears attempt and cooldown state after success" do
    service.record_success
    expect(CacheService).to have_received(:delete).with("password:attempts:#{user_id}")
    expect(CacheService).to have_received(:delete).with("password:cooldown:#{user_id}")
  end

  it "does not interrupt sign-in when cache cleanup fails" do
    allow(CacheService).to receive(:delete).and_raise("cache unavailable")
    expect { service.record_success }.not_to raise_error
  end
end
