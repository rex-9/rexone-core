# spec/services/passcode_attempt_service_spec.rb
require 'rails_helper'

RSpec.describe PasswordAttemptService do
  let(:user_id) { 1 }
  let(:service) { described_class.new(user_id: user_id) }

  before do
    # Clear Redis before each test
    PASSWORD_REDIS.flushdb
  end

  describe '#allowed?' do
    context 'with no previous attempts' do
      it 'returns true' do
        expect(service.allowed?).to be true
        expect(service.cooldown_remaining).to eq(0)
      end
    end

    context 'with attempts under limit' do
      before do
        2.times { service.record_failure }
      end

      it 'returns true' do
        expect(service.allowed?).to be true
        expect(service.cooldown_remaining).to eq(0)
      end
    end

    context 'with 3 failed attempts' do
      before do
        3.times { service.record_failure }
      end

      it 'triggers cooldown' do
        expect(service.allowed?).to be false
        expect(service.cooldown_remaining).to be > 0
      end
    end

    context 'with cooldown active' do
      before do
        3.times { service.record_failure }
        # Wait for cooldown to be set
        travel_to 1.second.from_now
      end

      it 'returns false during cooldown' do
        expect(service.allowed?).to be false
        expect(service.cooldown_remaining).to be > 0
      end

      it 'returns true after cooldown expires' do
        travel_to 31.seconds.from_now
        expect(service.allowed?).to be true
        expect(service.cooldown_remaining).to eq(0)
      end
    end
  end

  describe '#record_failure' do
    it 'tracks failure count' do
      result = service.record_failure
      expect(result[:failed_attempts]).to eq(1)
      expect(result[:lock_level]).to eq(0)
    end

    it 'triggers cooldown on 3rd failure' do
      2.times { service.record_failure }
      result = service.record_failure
      expect(result[:failed_attempts]).to eq(3)
      expect(result[:lock_level]).to eq(1)
      expect(result[:cooldown_remaining]).to eq(30)
    end

    it 'triggers 60s cooldown on 6th failure' do
      5.times { service.record_failure }
      result = service.record_failure
      expect(result[:failed_attempts]).to eq(6)
      expect(result[:lock_level]).to eq(2)
      expect(result[:cooldown_remaining]).to eq(60)
    end

    it 'triggers 120s cooldown on 9th failure' do
      8.times { service.record_failure }
      result = service.record_failure
      expect(result[:failed_attempts]).to eq(9)
      expect(result[:lock_level]).to eq(3)
      expect(result[:cooldown_remaining]).to eq(120)
    end

    it 'resets attempts after cooldown' do
      3.times { service.record_failure }
      expect(service.allowed?).to be false

      travel_to 35.seconds.from_now
      expect(service.allowed?).to be true

      result = service.record_failure
      expect(result[:failed_attempts]).to eq(1)
    end
  end

  describe '#record_success' do
    before do
      2.times { service.record_failure }
    end

    it 'clears failure state' do
      service.record_success
      expect(service.allowed?).to be true
      expect(service.cooldown_remaining).to eq(0)

      # Should start fresh
      result = service.record_failure
      expect(result[:failed_attempts]).to eq(1)
    end
  end

  describe '#status' do
    before do
      2.times { service.record_failure }
    end

    it 'returns full state' do
      status = service.status
      expect(status[:failed_attempts]).to eq(2)
      expect(status[:lock_level]).to eq(0)
      expect(status[:locked]).to be false
      expect(status[:cooldown_remaining]).to eq(0)
    end
  end

  describe '#locked?' do
    context 'with no cooldown' do
      it 'returns locked: false' do
        expect(service.locked?[:locked]).to be false
      end
    end

    context 'with active cooldown' do
      before do
        3.times { service.record_failure }
      end

      it 'returns locked: true' do
        expect(service.locked?[:locked]).to be true
        expect(service.locked?[:cooldown_remaining]).to be > 0
      end
    end
  end

  describe 'Redis failure handling' do
    before do
      allow(PASSWORD_REDIS).to receive(:eval).and_raise(Redis::BaseError.new("Connection failed"))
    end

    it 'fails open on Redis error' do
      expect(service.allowed?).to be true
      expect(service.record_failure[:failed_attempts]).to eq(1)
      expect(service.status[:locked]).to be false
    end
  end
end