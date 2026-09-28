# frozen_string_literal: true

require "rails_helper"

RSpec.describe "In-App Payment Providers" do
  describe Payment::Providers::AppStore do
    subject(:provider) { described_class.new }

    describe "webhook notification constants and support" do
      it "recognizes all canonical App Store notification types" do
        PaymentConstants::AppStoreNotificationType::ALL.each do |event_type|
          expect(provider.supported_webhook_event?(event_type)).to be(true)
          expect(provider.supported_webhook_event?(event_type.downcase)).to be(true)
        end
      end

      it "rejects unsupported notification types" do
        expect(provider.supported_webhook_event?("INVALID_TYPE")).to be(false)
        expect(provider.supported_webhook_event?("random_event")).to be(false)
      end
    end
  end

  describe Payment::Providers::GooglePlay do
    subject(:provider) { described_class.new }

    describe "webhook notification constants and support" do
      it "recognizes all canonical Google Play notification types" do
        PaymentConstants::GooglePlayNotificationType::ALL.each do |event_type|
          expect(provider.supported_webhook_event?(event_type)).to be(true)
          expect(provider.supported_webhook_event?(event_type.downcase)).to be(true)
        end
      end

      it "rejects unsupported notification types" do
        expect(provider.supported_webhook_event?("INVALID_TYPE")).to be(false)
        expect(provider.supported_webhook_event?("random_event")).to be(false)
      end
    end
  end
end
